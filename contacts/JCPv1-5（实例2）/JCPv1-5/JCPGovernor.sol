// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IJCPToken
 * @dev 扩展接口，包含税率调整、国库设置及黑名单功能
 */
interface IJCPToken is IERC20 {
    function setLaborTaxRate(uint256 newRate) external;
    function setCapitalTaxRate(uint256 newRate) external;
    function setTreasury(address _newTreasury) external;
    function addToBlacklist(address account) external;
    function removeFromBlacklist(address account) external;
}

/**
 * @title JCPGovernor
 * @notice 优化版治理合约：针对政策类提案强制执行零地址逻辑
 */
contract JCPGovernor is Ownable {
    IJCPToken public jcpToken;

    struct Proposal {
        uint256 id;
        string description;
        uint8 policyType;    // 1-2: 政策类, 3-6: 动作类
        uint256 targetValue;
        address targetAddr;
        uint256 startBlock;   // 提案发起时的区块（锁定权重）
        uint256 endBlock;     // 提案截止区块
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;

    // 默认治理窗口与参与率设置
    uint256 public policyVotingBlocks = 50; 
    uint256 public actionVotingBlocks = 25; 
    uint256 public quorumNumerator = 5;     

    event ProposalCreated(uint256 id, uint8 policyType, string desc, uint256 endBlock);
    event ProposalExecuted(uint256 id);

    constructor(address _jcpToken) Ownable(msg.sender) {
        jcpToken = IJCPToken(_jcpToken);
    }

    // --- 治理参数设置 ---

    function setVotingWindows(uint256 _policyBlocks, uint256 _actionBlocks) external onlyOwner {
        policyVotingBlocks = _policyBlocks;
        actionVotingBlocks = _actionBlocks;
    }

    function setQuorum(uint256 _numerator) external onlyOwner {
        require(_numerator <= 100, "Invalid percentage");
        quorumNumerator = _numerator;
    }

    // --- 核心业务逻辑 ---

    /**
     * @notice 发起提案
     * @param _policyType 1-2 为政策类，3-6 为动作类
     * @param _newAddr 用户输入的地址（在类型 1-2 中会被合约自动无视）
     */
    function propose(
        uint8 _policyType, 
        uint256 _value, 
        address _newAddr, 
        string memory _desc
    ) external returns (uint256) {
        require(jcpToken.balanceOf(msg.sender) > 0, "Hold JCP to propose");
        require(_policyType >= 1 && _policyType <= 6, "Type 1-6 only");

        uint256 votingPeriod;
        address finalAddr;

        // 核心修改：逻辑分离与地址强制转换
        if (_policyType <= 2) {
            // 政策类提案：使用政策类窗口，并强制地址为 0
            votingPeriod = policyVotingBlocks;
            finalAddr = address(0); 
        } else {
            // 动作类提案：使用动作类窗口，且必须传入有效非零地址
            votingPeriod = actionVotingBlocks;
            require(_newAddr != address(0), "Action requires valid target address");
            finalAddr = _newAddr;
        }

        proposalCount++;
        Proposal storage p = proposals[proposalCount];
        p.id = proposalCount;
        p.description = _desc;
        p.policyType = _policyType;
        p.targetValue = _value;
        p.targetAddr = finalAddr;
        p.startBlock = block.number; 
        p.endBlock = block.number + votingPeriod;

        emit ProposalCreated(proposalCount, _policyType, _desc, p.endBlock);
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
        require(!p.executed, "Executed already");
        
        uint256 requiredQuorum = (jcpToken.totalSupply() * quorumNumerator) / 100;
        require(p.forVotes >= requiredQuorum, "Quorum failed");
        require(p.forVotes > p.againstVotes, "Rejected by majority");

        p.executed = true;

        if (p.policyType == 1) {
            jcpToken.setLaborTaxRate(p.targetValue);
        } else if (p.policyType == 2) {
            jcpToken.setCapitalTaxRate(p.targetValue);
        } else if (p.policyType == 3) {
            jcpToken.setTreasury(p.targetAddr);
        } else if (p.policyType == 4) {
            uint256 amount = p.targetValue * 10**18;
            jcpToken.transfer(p.targetAddr, amount);
        } else if (p.policyType == 5) {
            jcpToken.addToBlacklist(p.targetAddr);
        } else if (p.policyType == 6) {
            jcpToken.removeFromBlacklist(p.targetAddr);
        }

        emit ProposalExecuted(_id);
    }

    // --- 增强版看板函数 ---

    function getProposalStatus(uint256 _id) public view returns (
        uint256 id,
        string memory contentSummary,
        string memory description,
        uint256 deadline,
        uint256 forV,
        uint256 againstV,
        bool quorumMet,
        string memory currentStatus
    ) {
        Proposal storage p = proposals[_id];
        require(_id > 0 && _id <= proposalCount, "ID out of range");

        id = p.id;
        description = p.description;
        deadline = p.endBlock;
        forV = p.forVotes;
        againstV = p.againstVotes;

        string[7] memory typeNames = ["", "LaborTax", "CapitalTax", "Treasury", "Subsidy", "Freeze", "Unfreeze"];
        contentSummary = string(abi.encodePacked("ID:", uint2str(p.id), " | ", typeNames[p.policyType], " | Val:", uint2str(p.targetValue)));
        
        uint256 q = (jcpToken.totalSupply() * quorumNumerator) / 100;
        quorumMet = (p.forVotes >= q);

        if (p.executed) {
            currentStatus = "Executed";
        } else if (block.number < p.endBlock) {
            currentStatus = "Active";
        } else if (quorumMet && p.forVotes > p.againstVotes) {
            currentStatus = "Passed (Ready)";
        } else {
            currentStatus = "Failed";
        }
    }

    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 len;
        while (j != 0) { len++; j /= 10; }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bstr[k] = bytes1(temp);
            _i /= 10;
        }
        return string(bstr);
    }
}