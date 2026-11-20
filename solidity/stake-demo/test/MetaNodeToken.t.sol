// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";

import {MetaNodeToken} from "../src/MetaNodeToken.sol";

contract MetaNodeTokenTest is Test {
    MetaNodeToken public vault;
    address public owner;
    address public recipient;
    function setUp() public {
        owner = makeAddr("owner");
        recipient = makeAddr("receipient");

        vault = new MetaNodeToken();
    }
    //  获取之智能合约中的初始balance
    function test_Blance() public {
        vm.prank(owner);
        uint256 expectSupply = 1000000 * 10 ** 18;
        uint256 totalSupply = vault.totalSupply();

        assertEq(totalSupply, expectSupply);
    }
}
