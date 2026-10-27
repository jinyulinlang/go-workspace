// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {BeggingContract} from "../src/BeggingContract.sol";
import {Test} from "forge-std/Test.sol";

contract BeggingContractTest is Test {
    BeggingContract public beggingContract;
    address public donor;

    function setUp() public {
        beggingContract = new BeggingContract();
        donor = makeAddr("donor");
        // 给 donor 1 ether
        vm.deal(donor, 1 ether);
    }

    function test_Donate() public {
        // 让下一次合约调用的 msg.sender 暂时变成 donor
        vm.prank(donor);
        beggingContract.donate{value: 0.2 ether}();
        assertEq(beggingContract.contributers(donor), 0.2 ether);
    }
    function test_DonateEmitEvent() public {
        // 期望发出事件 第一个参数有索引,最后一个参数有值
        vm.expectEmit(true, false, false, true);
        emit BeggingContract.Contributed(donor, 0.2 ether);
        vm.prank(donor);
        beggingContract.donate{value: 0.2 ether}();
    }
    function test_RevertWhenDonationTooSMall() public {
        vm.prank(donor);
        vm.expectRevert(
            bytes("the donate value must be greater than 0.1 ether")
        );
        beggingContract.donate{value: 0.1 ether}();
    }

    // 接受以太币
    receive() external payable {}
    function test_WithDrawn() public {
        vm.prank(donor);
        beggingContract.donate{value: 0.2 ether}();
        vm.prank(address(this));
        // 讨饭合约取出 0.2 ether

        beggingContract.withdraw();
        // 讨饭合约的余额应该是 0
        assertEq(address(beggingContract).balance, 0);
    }

    function test_GetDonation() public {
        vm.prank(donor);
        beggingContract.donate{value: 0.2 ether}();
        assertEq(beggingContract.getDonation(donor), 0.2 ether);
    }
}
