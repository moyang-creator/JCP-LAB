// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IJCPToken
 * @dev 接口定义：确保 DAO 能精准调用 JCPTokenFull 的管理函数
 */
interface IJCPToken {
    function setLaborTaxRate(uint256 newRate) external;
    function setCapitalTaxRate(uint256 newRate) external;
    function setTreasury(address _newTreasury) external;
}

/**
 * @title JCPGovernorV5 - 终极优化版
 * @author Gemini Assistant for JCP Lab
 */
contract JCPGovernorV5 is Ownable {
    IERC20 public jcpToken;
    IJCPToken public targetToken;

    struct Proposal {
        string description;
        uint8 policyType;    // 1:劳动税, 2:资本税, 3:改国库, 4:发补贴
        uint256 targetValue;
        address targetAddr;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    uint256 public votingBlocks = 25; // 默认约 5 分钟

    event ProposalCreated(uint256 id, uint8 policyType, string desc);
    event ProposalExecuted(uint256 id);

    constructor(address _jcpToken, address _targetToken) Ownable(msg.sender) {
        jcpToken = IERC20(_jcpToken);
        targetToken = IJCPToken(_targetToken);
    }

    // --- 教师权限功能 ---

    function setVotingPeriod(uint256 _newBlocks) external onlyOwner {
        votingBlocks = _newBlocks;
    }

    // --- 核心治理流程 ---

    /**
     * @notice 发起提案 (优化版：调税无需手动输入零地址)
     * @param _policyType 1:劳动税, 2:资本税, 3:改国库, 4:发补贴
     * @param _value 数值 (税率 BP 或 补贴整数)
     * @param _newAddr 目标地址 (调税时可留空)
     * @param _desc 提案描述
     */
    function propose(
        uint8 _policyType, 
        uint256 _value, 
        address _newAddr, 
        string memory _desc
    ) external returns (uint256) {
        require(jcpToken.balanceOf(msg.sender) > 0, "Hold JCP to propose");
        require(_policyType >= 1 && _policyType <= 4, "Type must be 1-4");

        // 自动化 UX 处理：
        address finalAddr = _newAddr;
        
        if (_policyType == 1 || _policyType == 2) {
            // 调税时，系统自动忽略地址输入，统一设为零地址
            finalAddr = address(0);
        } else if ((_policyType == 3 || _policyType == 4) && _newAddr == address(0)) {
            // 关键财务操作，如果学生忘记填地址，直接报错拦截
            revert("Address REQUIRED for Treasury/Subsidy");
        }

        proposalCount++;
        Proposal storage p = proposals[proposalCount];
        p.description = _desc;
        p.policyType = _policyType;
        p.targetValue = _value;
        p.targetAddr = finalAddr;
        p.endBlock = block.number + votingBlocks;

        emit ProposalCreated(proposalCount, _policyType, _desc);
        return proposalCount;
    }

    function vote(uint256 _id, bool _support) external {
        Proposal storage p = proposals[_id];
        require(block.number < p.endBlock, "Voting ended");
        require(!p.hasVoted[msg.sender], "Voted already");

        uint256 weight = jcpToken.balanceOf(msg.sender);
        require(weight > 0, "No voting weight");

        p.hasVoted[msg.sender] = true;
        if (_support) p.forVotes += weight;
        else p.againstVotes += weight;
    }

    function executeProposal(uint256 _id) external {
        Proposal storage p = proposals[_id];
        require(block.number >= p.endBlock, "Voting active");
        require(p.forVotes > p.againstVotes, "Majority rejected");
        require(!p.executed, "Executed already");

        p.executed = true;

        if (p.policyType == 1) {
            targetToken.setLaborTaxRate(p.targetValue);
        } else if (p.policyType == 2) {
            targetToken.setCapitalTaxRate(p.targetValue);
        } else if (p.policyType == 3) {
            targetToken.setTreasury(p.targetAddr);
        } else if (p.policyType == 4) {
            // 自动换算：1 JCP = 10^18 units
            uint256 finalAmount = p.targetValue * 10**18;
            require(jcpToken.balanceOf(address(this)) >= finalAmount, "Treasury empty");
            jcpToken.transfer(p.targetAddr, finalAmount);
        }

        emit ProposalExecuted(_id);
    }

    // --- 增强版可视化看板 ---

    function checkProposalDashboard(uint256 _id) public view returns (
        string memory typeDesc,
        string memory status,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 blocksLeft,
        string memory details
    ) {
        Proposal storage p = proposals[_id];
        require(_id > 0 && _id <= proposalCount, "Invalid ID");
        
        string[5] memory typeNames = ["", "LaborTax (1)", "CapitalTax (2)", "Treasury (3)", "Subsidy (4)"];
        typeDesc = typeNames[p.policyType];

        if (p.executed) {
            status = "SUCCESS: Executed";
        } else if (block.number < p.endBlock) {
            status = "PENDING: Voting Active";
        } else if (p.forVotes > p.againstVotes) {
            status = "READY: Passed - Please Execute";
        } else {
            status = "FAILED: Defeated";
        }

        forVotes = p.forVotes;
        againstVotes = p.againstVotes;
        blocksLeft = (block.number < p.endBlock) ? (p.endBlock - block.number) : 0;
        details = p.description;
    }
}