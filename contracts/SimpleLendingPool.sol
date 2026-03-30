// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleLendingPool is Ownable {
    IERC20 public stablecoin;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public lastDepositTime;

    uint256 public constant INTEREST_RATE = 5; // 年化 5%

    constructor(address _stablecoin) Ownable(msg.sender) {
        stablecoin = IERC20(_stablecoin);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        stablecoin.transferFrom(msg.sender, address(this), amount);
        
        deposits[msg.sender] += amount;
        lastDepositTime[msg.sender] = block.timestamp;
        
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount, "Insufficient deposit");
        
        uint256 interest = calculateInterest(msg.sender);
        uint256 totalAmount = amount + interest;
        
        deposits[msg.sender] -= amount;
        if (deposits[msg.sender] == 0) {
            delete lastDepositTime[msg.sender];
        }
        
        stablecoin.transfer(msg.sender, totalAmount);
        emit Withdrawn(msg.sender, amount, interest);
    }

    function calculateInterest(address user) public view returns (uint256) {
        if (lastDepositTime[user] == 0) return 0;
        uint256 timePassed = block.timestamp - lastDepositTime[user];
        return (deposits[user] * INTEREST_RATE * timePassed) / (365 days * 100);
    }

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 principal, uint256 interest);
}
