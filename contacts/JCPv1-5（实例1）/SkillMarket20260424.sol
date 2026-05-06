// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IJCPMintable {
    function mint(address to, uint256 amount) external;
}

/**
 * @title SkillMarket
 * @dev 动态配置版：支持在不重新部署的情况下更换代币合约地址
 */
contract SkillMarket {
    // --- 配置 ---
    // 去掉 immutable，使其变为可修改的状态变量
    IJCPMintable public jcpToken; 
    address public owner;

    // --- 状态变量 ---
    uint256 public rewardPerTask = 20 * 10**18;
    mapping(bytes32 => bool) public usedAnswers;

    // --- 事件 ---
    event SkillSold(address indexed student, bytes32 answerHash, uint256 reward);
    event TokenAddressUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @param _jcpTokenAddress 初始代币地址
     */
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
     * @dev 【核心功能】手动改动绑定的代币合约地址
     * 有了这个函数，以后 JCPTokenFull 升级了，只需要调用此函数即可，无需重刷市场
     */
    function setTokenAddress(address _newJCP) external onlyOwner {
        require(_newJCP != address(0), "Invalid JCP address");
        address oldJCP = address(jcpToken);
        jcpToken = IJCPMintable(_newJCP);
        emit TokenAddressUpdated(oldJCP, _newJCP);
    }

    /**
     * @dev 提交劳动成果换取代币
     */
    function sellSkill(string calldata answer) external {
        bytes32 answerHash = keccak256(abi.encodePacked(answer));
        require(!usedAnswers[answerHash], "This labor is not unique!");

        usedAnswers[answerHash] = true;

        try jcpToken.mint(msg.sender, rewardPerTask) {
            emit SkillSold(msg.sender, answerHash, rewardPerTask);
        } catch {
            revert("Minting failed: SkillMarket lacks MINTER_ROLE on the linked JCP contract.");
        }
    }

    /**
     * @dev 教学辅助查询
     */
    function getSystemRoles() public view returns (
        address linkedJCPToken,
        address currentMarketAddress,
        uint256 currentReward,
        string memory tip
    ) {
        return (
            address(jcpToken), 
            address(this), 
            rewardPerTask,
            "Tip: If you updated JCP contract, use setTokenAddress to re-link it."
        );
    }

    function setRewardAmount(uint256 newAmount) external onlyOwner {
        rewardPerTask = newAmount;
    }
}