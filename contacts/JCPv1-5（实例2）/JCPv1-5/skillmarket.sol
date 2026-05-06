// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IJCPMintable {
    function mint(address to, uint256 amount) external;
}

/**
 * @title SkillMarket - 增强记录与去重版
 * @dev 支持统计总数、查看历史记录，并确保劳动成果的独特性
 */
contract SkillMarket {
    // --- 结构体与记录 ---
    struct SkillRecord {
        address student;     // 提交者地址
        string content;      // 提交的原始文本内容
        uint256 timestamp;   // 提交时间戳
        uint256 reward;      // 获得的奖励数额
    }

    // --- 配置与状态变量 ---
    IJCPMintable public jcpToken; 
    address public owner;
    uint256 public rewardPerTask = 20 * 10**18;

    // 需求 1: 记录提交的总数
    uint256 public totalSkillsSubmitted; 

    // 需求 2: 记录所有已提交的历史数据
    SkillRecord[] public allRecords; 

    // 需求 3: 确保信息不重复（保持原有的哈希映射校验）
    mapping(bytes32 => bool) public usedAnswers;

    // --- 事件 ---
    event SkillSold(address indexed student, bytes32 answerHash, uint256 reward);
    event TokenAddressUpdated(address indexed oldAddress, address indexed newAddress);

    constructor(address _jcpTokenAddress) {
        require(_jcpTokenAddress != address(0), "Invalid address");
        jcpToken = IJCPMintable(_jcpTokenAddress);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    /**
     * @dev 提交劳动成果（增加去重与记录功能）
     */
    function sellSkill(string calldata answer) external {
        // 核心校验：只有不重复的独特信息才能被接受
        bytes32 answerHash = keccak256(abi.encodePacked(answer));
        require(!usedAnswers[answerHash], "This labor is not unique!");

        usedAnswers[answerHash] = true;

        // 记录逻辑更新
        allRecords.push(SkillRecord({
            student: msg.sender,
            content: answer,
            timestamp: block.timestamp,
            reward: rewardPerTask
        }));
        totalSkillsSubmitted++; // 更新总数

        try jcpToken.mint(msg.sender, rewardPerTask) {
            emit SkillSold(msg.sender, answerHash, rewardPerTask);
        } catch {
            revert("Minting failed: SkillMarket lacks MINTER_ROLE on the linked JCP contract.");
        }
    }

    /**
     * @dev 获取所有提交记录的列表
     * @return 返回 SkillRecord 数组，方便前端或管理端查看所有历史
     */
    function getAllRecords() external view returns (SkillRecord[] memory) {
        return allRecords;
    }

    /**
     * @dev 分页查询记录（防止历史记录过多导致 Gas 超限）
     * @param offset 起始索引
     * @param limit 查询数量
     */
    function getRecordsPaged(uint256 offset, uint256 limit) external view returns (SkillRecord[] memory) {
        uint256 end = offset + limit;
        if (end > allRecords.length) end = allRecords.length;
        
        SkillRecord[] memory paged = new SkillRecord[](end - offset);
        for (uint256 i = 0; i < (end - offset); i++) {
            paged[i] = allRecords[offset + i];
        }
        return paged;
    }

    // --- 系统管理与查询 ---

    function setTokenAddress(address _newJCP) external onlyOwner {
        require(_newJCP != address(0), "Invalid JCP address");
        address oldJCP = address(jcpToken);
        jcpToken = IJCPMintable(_newJCP);
        emit TokenAddressUpdated(oldJCP, _newJCP);
    }

    function getSystemInfo() public view returns (
        address linkedJCPToken,
        uint256 totalSubmitted,
        uint256 currentReward,
        string memory tip
    ) {
        return (
            address(jcpToken), 
            totalSkillsSubmitted, 
            rewardPerTask,
            "History can be viewed via getAllRecords()"
        );
    }

    function setRewardAmount(uint256 newAmount) external onlyOwner {
        rewardPerTask = newAmount;
    }
}