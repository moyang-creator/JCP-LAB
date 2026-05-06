// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IJCPToken
 * @dev 接口定义：支持税率调整、国库转账授权验证、以及黑名单管理
 */
interface IJCPToken is IERC20 {
    function setLaborTaxRate(uint256 newRate) external;
    function setCapitalTaxRate(uint256 newRate) external;
    function addToBlacklist(address account) external;
    function removeFromBlacklist(address account) external;
}

/**
 * @title JCPGovernor
 * @notice 宏观经济实验室治理合约 - 独立国库控制版
 */
contract JCPGovernor is Ownable {
    IJCPToken public jcpToken;
    address public treasury; // 独立的国库地址

    struct Proposal {
        uint256 id;
        string description;
        uint8 policyType;    // 1-2: 政策类, 3: 改国库, 4: 发补贴, 5-6: 黑名单
        uint256 targetValue;
        address targetAddr;
        uint256 startBlock;   
        uint256 endBlock;     
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;

    // 治理时间窗口与参与率
    uint256 public policyVotingBlocks = 50; 
    uint256 public actionVotingBlocks = 25; 
    uint256 public quorumNumerator = 5;     

    // 规范零地址常量
    address public constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    event ProposalCreated(uint256 id, uint8 policyType, string desc, uint256 endBlock);
    event ProposalExecuted(uint256 id);
    event TreasuryChanged(address oldTreasury, address newTreasury);

    /**
     * @param _jcpToken 代币地址
     * @param _initialTreasury 初始国库地址 (学生补贴资金存放处)
     */
    constructor(address _jcpToken, address _initialTreasury) Ownable(msg.sender) {
        jcpToken = IJCPToken(_jcpToken);
        treasury = _initialTreasury;
    }

    // --- 管理接口 ---

    function setVotingWindows(uint256 _policyBlocks, uint256 _actionBlocks) external onlyOwner {
        policyVotingBlocks = _policyBlocks;
        actionVotingBlocks = _actionBlocks;
    }

    function setQuorum(uint256 _numerator) external onlyOwner {
        require(_numerator <= 100, "Invalid percentage");
        quorumNumerator = _numerator;
    }

    // --- 核心治理流程 ---

    /**
     * @notice 发起提案
     * @param _policyType 1-2: 政策, 3: 改国库, 4: 发补贴, 5: 冻结, 6: 解冻
     */
    function propose(
        uint8 _policyType, 
        uint256 _value, 
        address _newAddr, 
        string memory _desc
    ) external returns (uint256) {
        require(jcpToken.balanceOf(msg.sender) > 0, "Must hold JCP to propose");
        require(_policyType >= 1 && _policyType <= 6, "Invalid policy type");

        uint256 votingPeriod;
        address finalAddr;

        if (_policyType <= 2) {
            // 政策类提案：使用政策窗口，强制使用规范零地址
            votingPeriod = policyVotingBlocks;
            finalAddr = ZERO_ADDRESS; 
        } else {
            // 动作类提案：使用动作窗口，校验地址有效性
            votingPeriod = actionVotingBlocks;
            require(_newAddr != address(0), "Action requires target address");
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
        require(!p.hasVoted[msg.sender], "Already voted");

        uint256 weight = jcpToken.balanceOf(msg.sender);
        require(weight > 0, "No weight");

        p.hasVoted[msg.sender] = true;
        if (_support) p.forVotes += weight;
        else p.againstVotes += weight;
    }

    /**
     * @notice 执行提案
     * @dev 包含国库转账授权逻辑
     */
    function executeProposal(uint256 _id) external {
        Proposal storage p = proposals[_id];
        require(block.number >= p.endBlock, "Voting active");
        require(!p.executed, "Executed");
        
        uint256 requiredQuorum = (jcpToken.totalSupply() * quorumNumerator) / 100;
        require(p.forVotes >= requiredQuorum, "Quorum unmet");
        require(p.forVotes > p.againstVotes, "Majority rejected");

        p.executed = true;

        if (p.policyType == 1) {
            jcpToken.setLaborTaxRate(p.targetValue);
        } else if (p.policyType == 2) {
            jcpToken.setCapitalTaxRate(p.targetValue);
        } else if (p.policyType == 3) {
            // 修改国库地址
            address old = treasury;
            treasury = p.targetAddr;
            emit TreasuryChanged(old, treasury);
        } else if (p.policyType == 4) {
            // 从独立国库地址发放补贴
            uint256 amount = p.targetValue * 10**18;
            // 需确保 treasury 地址已对本合约执行了 approve
            require(
                jcpToken.transferFrom(treasury, p.targetAddr, amount),
                "Treasury transfer failed: Check allowance/balance"
            );
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
        string memory summary,
        string memory desc,
        address currentTreasury,
        uint256 deadline,
        uint256 forV,
        uint256 againstV,
        string memory state
    ) {
        Proposal storage p = proposals[_id];
        require(_id > 0 && _id <= proposalCount, "Invalid ID");

        id = p.id;
        desc = p.description;
        currentTreasury = treasury;
        deadline = p.endBlock;
        forV = p.forVotes;
        againstV = p.againstVotes;

        string[7] memory typeNames = ["", "LaborTax", "CapitalTax", "SetTreasury", "SendSubsidy", "Freeze", "Unfreeze"];
        summary = string(abi.encodePacked("T:", typeNames[p.policyType], " | V:", uint2str(p.targetValue), " | A:", addressToString(p.targetAddr)));
        
        uint256 q = (jcpToken.totalSupply() * quorumNumerator) / 100;
        bool quorumMet = (p.forVotes >= q);

        if (p.executed) state = "Executed";
        else if (block.number < p.endBlock) state = "Active";
        else if (quorumMet && p.forVotes > p.againstVotes) state = "Passed";
        else state = "Failed";
    }

    // --- 工具函数 ---

    function uint2str(uint256 _i) internal pure returns (string memory) {
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

    function addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3+i*2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }
}