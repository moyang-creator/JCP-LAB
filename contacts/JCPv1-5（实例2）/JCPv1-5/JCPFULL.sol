// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title JCPTokenFull - 增强版（含黑名单与资产冻结）
 */
contract JCPTokenFull is ERC20, ERC20Permit, ERC20Votes, AccessControl {
    // --- 角色定义 ---
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); 
    bytes32 public constant POLICY_ROLE = keccak256("POLICY_ROLE");
    // 新增：黑名单管理角色
    bytes32 public constant BLACKLIST_ROLE = keccak256("BLACKLIST_ROLE");

    // --- 状态变量 ---
    address public treasury; 
    uint256 public laborTaxRate = 2000;   // 20%
    uint256 public capitalTaxRate = 500;  // 5%

    // 新增：黑名单映射表
    mapping(address => bool) private _blacklisted;

    // 事件
    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);

    constructor(address _treasury, address _admin) 
        ERC20("JCP Governance Coin", "JCP") 
        ERC20Permit("JCP Governance Coin") 
    {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
        _grantRole(POLICY_ROLE, _admin);
        _grantRole(BLACKLIST_ROLE, _admin); // 初始授予管理员黑名单管理权
        
        _mint(_admin, 1000 * 10 ** decimals());
    }

    // --- 黑名单核心功能 ---

    /**
     * @dev 将地址加入黑名单（资产冻结）
     */
    function addToBlacklist(address account) external onlyRole(BLACKLIST_ROLE) {
        require(!_blacklisted[account], "Already blacklisted");
        _blacklisted[account] = true;
        emit Blacklisted(account);
    }

    /**
     * @dev 将地址移出黑名单
     */
    function removeFromBlacklist(address account) external onlyRole(BLACKLIST_ROLE) {
        require(_blacklisted[account], "Not blacklisted");
        _blacklisted[account] = false;
        emit Unblacklisted(account);
    }

    /**
     * @dev 查询地址是否被冻结
     */
    function isBlacklisted(address account) public view returns (bool) {
        return _blacklisted[account];
    }

    // --- 逻辑重写 ---

    function _update(address from, address to, uint256 value) 
        internal 
        override(ERC20, ERC20Votes) 
    {
        // 核心合规校验：发送方和接收方都不能在黑名单中
        require(!_blacklisted[from], "JCP: Sender account is frozen");
        require(!_blacklisted[to], "JCP: Receiver account is frozen");

        if (from != address(0) && to != address(0) && from != treasury && to != treasury) {
            uint256 taxAmount = (value * capitalTaxRate) / 10000;
            uint256 transferAmount = value - taxAmount;
            super._update(from, treasury, taxAmount);
            super._update(from, to, transferAmount);
        } else {
            super._update(from, to, value);
        }
    }

    // --- 管理函数 ---

    function setLaborTaxRate(uint256 newRate) public onlyRole(POLICY_ROLE) {
        require(newRate <= 5000, "Tax too high");
        laborTaxRate = newRate;
    }

    function setCapitalTaxRate(uint256 newRate) public onlyRole(POLICY_ROLE) {
        require(newRate <= 2000, "Tax too high");
        capitalTaxRate = newRate;
    }

    function setTreasury(address _newTreasury) public onlyRole(POLICY_ROLE) {
        require(_newTreasury != address(0), "Invalid address");
        treasury = _newTreasury;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        uint256 tax = (amount * laborTaxRate) / 10000;
        uint256 netReward = amount - tax;
        _mint(treasury, tax);
        _mint(to, netReward);
    }

    // --- 辅助与兼容性函数 ---

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    /**
     * @dev 优化后的系统信息辅助函数 [修正项]
     */
    function getSystemInfo() public pure returns (
        bytes32 minter, 
        bytes32 policy,
        bytes32 blacklist,
        bytes32 admin,
        string memory tip
    ) {
        return (
            MINTER_ROLE, 
            POLICY_ROLE, 
            BLACKLIST_ROLE,
            DEFAULT_ADMIN_ROLE, 
            "Use these hashes in grantRole to manage permissions"
        );
    }
}