// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {MyNFT} from "../src/MyNFT.sol";
import {Test} from "forge-std/Test.sol";

contract MyNFTTest is Test {
    MyNFT public vault;
    address public owner;
    address public recipient;
    function setUp() public {
        owner = makeAddr("owner");
        recipient = makeAddr("recipient");
        vault = new MyNFT(owner, "MyNFT", "NFT");
    }

    // 测试铸造
    function test_Mint() public {
        vm.prank(owner);

        vault.mint(recipient);

        assertEq(vault.ownerOf(0), recipient);
    }
    // 测试转移
    function test_Transfer() public {
        vm.prank(owner);
        vault.mint(recipient);

        vm.prank(recipient);
        vault.transferFrom(recipient, owner, 0);

        assertEq(vault.ownerOf(0), owner);
    }
}
