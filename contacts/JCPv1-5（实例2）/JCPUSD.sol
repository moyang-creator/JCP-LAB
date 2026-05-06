// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24; // 已更新为支持 OpenZeppelin v5.0+ 的版本

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract JCPToken is ERC20, Ownable, ERC20Permit, ERC20Votes {
    /**
     * @dev 构造函数：在部署时执行
     * @param initialOwner 填入您的钱包地址（即“央行”地址）
     */
    constructor(address initialOwner)
        ERC20("JCP Coin", "JCP")
        Ownable(initialOwner)
        ERC20Permit("JCP Coin")
    {
        // --- 逻辑变更点 ---
        // 初始铸造 1000 个币给您自己（央行）
        // 10 ** decimals() 是为了处理 ERC20 的 18 位精度
        _mint(initialOwner, 1000 * 10 ** decimals());
    }

    /**
     * @dev 铸币权限：未来将移交给 WorkContract
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    // 以下为必要的标准重写函数
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}