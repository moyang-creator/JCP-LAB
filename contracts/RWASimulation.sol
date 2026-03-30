// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RWASimulation is ERC721, Ownable {
    uint256 private _nextTokenId;
    mapping(uint256 => uint256) public assetValue;
    mapping(uint256 => string) public assetDescription;

    constructor() ERC721("RealWorldAsset", "RWA") Ownable(msg.sender) {}

    function mintRWA(address to, uint256 valueInUSD, string memory description) 
        external 
        onlyOwner 
    {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        
        assetValue[tokenId] = valueInUSD;
        assetDescription[tokenId] = description;
        
        emit RWAMinted(tokenId, to, valueInUSD, description);
    }

    function transferFrom(address from, address to, uint256 tokenId) 
        public 
        override 
    {
        super.transferFrom(from, to, tokenId);
        emit RWATransferred(tokenId, from, to, assetValue[tokenId]);
    }

    function getAssetValue(uint256 tokenId) external view returns (uint256) {
        return assetValue[tokenId];
    }

    event RWAMinted(uint256 indexed tokenId, address indexed owner, uint256 valueInUSD, string description);
    event RWATransferred(uint256 indexed tokenId, address from, address to, uint256 valueInUSD);
}
