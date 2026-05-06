// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// 为了能调用 JCPToken 的销毁功能，我们需要定义一个简单的接口
interface IJCPBurnable is IERC20 {
    function burn(uint256 amount) external;
}

/**
 * @title JCPTreasury
 * @dev 模拟财政部。管理公共资金，执行再分配（补贴）或紧缩政策（销毁）。
 */
contract JCPTreasury is AccessControl {
    // 【配置】代币接口，此处使用可销毁接口以支持紧缩政策
    IJCPBurnable public immutable jcpToken;

    // --- 事件记录 ---
    event SubsidyDistributed(address indexed recipient, uint256 amount);
    event ReservesBurned(uint256 amount);

    /**
     * @param _jcpAddress 部署好的 JCPTokenFull 合约地址
     */
    constructor(address _jcpAddress) {
        require(_jcpAddress != address(0), "Invalid address");
        jcpToken = IJCPBurnable(_jcpAddress);
        
        // 将部署者（教师）设为最高管理员
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev 【关键词：Subsidy】财政补贴。
     * 逻辑：将国库积累的税收（之前 mint 和 _update 产生的税）重新分发。
     */
    function giveSubsidy(address student, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // 检查国库余额是否充足
        require(jcpToken.balanceOf(address(this)) >= amount, "Treasury: Insufficient balance!");
        
        // 执行转账
        jcpToken.transfer(student, amount);
        emit SubsidyDistributed(student, amount);
    }

    /**
     * @dev 【关键词：Batch Subsidy】批量补贴。
     * 一次性为多名学生发放等额补贴，提高教学演示效率。
     */
    function batchSubsidy(address[] calldata students, uint256 amountEach) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 totalNeeded = students.length * amountEach;
        require(jcpToken.balanceOf(address(this)) >= totalNeeded, "Treasury: Insufficient balance for batch!");

        for (uint256 i = 0; i < students.length; i++) {
            jcpToken.transfer(students[i], amountEach);
            emit SubsidyDistributed(students[i], amountEach);
        }
    }

    /**
     * @dev 【关键词：Deflationary】紧缩政策（销毁存量）。
     * 如果市场上 JCP 太多导致贬值，通过销毁国库中的钱来维护货币价值。
     */
    function burnReserves(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(jcpToken.balanceOf(address(this)) >= amount, "Treasury: Not enough to burn");
        
        // 直接调用 JCPToken 合约自带的 burn 函数
        jcpToken.burn(amount);
        emit ReservesBurned(amount);
    }

    /**
     * @dev 教学辅助函数：在 Read 区域一键获取国库状态
     */
    function getSystemRoles() public view returns (
        address currentTreasury,
        uint256 balance,
        string memory tip
    ) {
        return (
            address(this),
            jcpToken.balanceOf(address(this)),
            "Check balance here to see tax revenue accumulated from minting and transfers."
        );
    }
}