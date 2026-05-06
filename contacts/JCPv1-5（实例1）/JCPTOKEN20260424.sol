// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24; // 声明编译器版本

// 引入 OpenZeppelin 标准库
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // 基础 ERC20 代币功能
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol"; // 支持无 Gas 签名授权功能
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol"; // 支持链上投票和快照功能（DAO 基础）
import "@openzeppelin/contracts/access/AccessControl.sol"; // 基于角色的权限控制库

/**
 * @title JCPTokenFull
 * @dev 旗舰版合约：集成了治理、授权、角色管理和税收模型
 */
contract JCPTokenFull is ERC20, ERC20Permit, ERC20Votes, AccessControl {
    // --- 角色定义 ---
    // 定义铸币者角色哈希，设为 public 方便学生在界面直接看到（若不想去侧边栏看）
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); 
    // 定义政策制定者角色哈希，负责调整税率
    bytes32 public constant POLICY_ROLE = keccak256("POLICY_ROLE");

    // --- 状态变量 ---
    address public treasury; // 国库地址，所有的税收代币将汇入此处

    // 税率分母默认为 10000（即基点 BP）
    uint256 public laborTaxRate = 2000;   // 劳动税率：2000/10000 = 20% (铸币时收取)
    uint256 public capitalTaxRate = 500;  // 资本税率：500/10000 = 5% (转账时收取)

    /**
     * @dev 构造函数：初始化代币信息及初始权限
     * @param _treasury 国库地址
     * @param _admin 管理员地址
     */
    constructor(address _treasury, address _admin) 
        ERC20("JCP Governance Coin", "JCP") // 设置代币名称和符号
        ERC20Permit("JCP Governance Coin") // 设置 EIP-712 签名域名称
    {
        treasury = _treasury; // 初始化国库地址
        _grantRole(DEFAULT_ADMIN_ROLE, _admin); // 授予管理员最高权限（可授权他人）
        _grantRole(MINTER_ROLE, _admin); // 授予管理员初始铸币权
        _grantRole(POLICY_ROLE, _admin); // 授予管理员初始税率调整权
        
        // 初始铸造 1000 个代币给管理员（自动处理 18 位小数）
        _mint(_admin, 1000 * 10 ** decimals());
    }

    // --- 核心修复：解决 ERC20Permit 与 ERC20Votes 之间的 nonces 冲突 ---
    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces) // 显式指出从这两个来源重写，消除歧义
        returns (uint256)
    {
        return super.nonces(owner); // 调用父类的逻辑
    }

    /**
     * @dev 修改劳动税率（仅限 POLICY_ROLE 角色）
     */
    function setLaborTaxRate(uint256 newRate) public onlyRole(POLICY_ROLE) {
        require(newRate <= 5000, "Tax too high"); // 限制税率最高不超过 50%
        laborTaxRate = newRate;
    }

    /**
     * @dev 修改资本税率（仅限 POLICY_ROLE 角色）
     */
    function setCapitalTaxRate(uint256 newRate) public onlyRole(POLICY_ROLE) {
        require(newRate <= 2000, "Tax too high"); // 限制税率最高不超过 20%
        capitalTaxRate = newRate;
    }

    /**
     * @dev 带税收机制的铸币函数（仅限 MINTER_ROLE 角色）
     * 逻辑：铸造总额中，一部分去国库，剩余部分给目标地址
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        uint256 tax = (amount * laborTaxRate) / 10000; // 计算劳动税
        uint256 netReward = amount - tax; // 计算用户实收金额
        _mint(treasury, tax); // 将税收部分铸造给国库
        _mint(to, netReward); // 将净额部分铸造给用户
    }

    /**
     * @dev 核心修复：处理 ERC20 与 ERC20Votes 之间的 _update 逻辑冲突
     * 并在转账过程中嵌入“资本税”逻辑
     */
    function _update(address from, address to, uint256 value) 
        internal 
        override(ERC20, ERC20Votes) // 显式重写两个父类的更新函数
    {
        // 逻辑：如果不是铸币/销毁，且不涉及国库地址，则扣除资本转账税
        if (from != address(0) && to != address(0) && from != treasury && to != treasury) {
            uint256 taxAmount = (value * capitalTaxRate) / 10000; // 计算税额
            uint256 transferAmount = value - taxAmount; // 计算实际到账金额
            super._update(from, treasury, taxAmount); // 将税额部分转移至国库
            super._update(from, to, transferAmount); // 将剩余部分转移至接收者
        } else {
            // 如果是铸币、销毁或涉及国库的转账，按原样执行不收税
            super._update(from, to, value);
        }
    }

    // --- 治理相关重写：将投票权重与时间戳绑定 ---
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp); // 使用当前区块时间戳作为投票计时的参考
    }

/**
 * @dev 调整国库地址（仅限 POLICY_ROLE 角色，通常是教师）
 * @param _newTreasury 新部署的 JCPTreasury 合约地址
 */
function setTreasury(address _newTreasury) public onlyRole(POLICY_ROLE) {
    require(_newTreasury != address(0), "Invalid address");
    treasury = _newTreasury;
}

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp"; // 告知治理工具（如 Tally）该代币使用时间戳模式
    }

    /**
     * @dev 用户销毁自己的代币
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    /**
     * @dev 教学辅助函数：在 Read 区域一键获取所有角色哈希值
     * 这样学生就不需要去代码里或者侧边栏到处找哈希了
     */
    function getSystemRoles() public pure returns (
        bytes32 minter, 
        bytes32 policy,
        bytes32 admin,
        string memory tip
    ) {
        return (
            MINTER_ROLE, 
            POLICY_ROLE, 
            DEFAULT_ADMIN_ROLE, 
            "Use these hashes in grantRole to authorize users"
        );
    }
}