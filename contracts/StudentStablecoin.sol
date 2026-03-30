// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract StudentStablecoin is ERC20, Ownable, Pausable {
    constructor() ERC20("StudentUSD", "sUSD") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external onlyOwner whenNotPaused {
        _mint(to, amount);
        emit StablecoinMinted(to, amount);
    }

    function burn(uint256 amount) external whenNotPaused {
        _burn(msg.sender, amount);
        emit StablecoinBurned(msg.sender, amount);
    }

    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }

    function transfer(address to, uint256 amount) 
        public 
        override 
        whenNotPaused 
        returns (bool) 
    {
        return super.transfer(to, amount);
    }

    event StablecoinMinted(address indexed to, uint256 amount);
    event StablecoinBurned(address indexed from, uint256 amount);
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);
}
