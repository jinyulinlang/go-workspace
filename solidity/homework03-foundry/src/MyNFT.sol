// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721, Ownable {
    uint256 private _nextTokenId;

    /// MyNFT 的构造函数
    constructor(
        address initalOwner
    ) ERC721("MyNFT", "NFT") Ownable(initalOwner) {}

    /// 支持 NFT 的铸造和转移(ERC721 本身支持 转移 )。
    function mint(address to) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
    }
}
