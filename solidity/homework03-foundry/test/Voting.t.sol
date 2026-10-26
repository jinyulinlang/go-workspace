// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Voting} from "../src/Voting.sol";
import {Test} from "forge-std/Test.sol";

contract VotingTest is Test {
    Voting public voting;

    // 创建2个用户
    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        voting = new Voting();
    }

    function test_Vote() public {
        voting.vote(user1, user2);
        uint256 voteNum = voting.getVotes(user2);
        assertEq(voteNum, 1);
    }
    function test_ResetVotes() public {
        voting.vote(user1, user2);
        voting.resetVotes();
        uint256 voteNum = voting.getVotes(user2);
        assertEq(voteNum, 0);
    }

    function test_RomanToInt() public view {
        uint256 num = voting.romanToInt("IV");
        assertEq(num, 4);
    }

    function test_IntToRoman() public view {
        string memory str = voting.intToRoman(4);
        assertEq(str, "IV");
    }

    function test_MergeArray() public view {
        uint256[] memory arr1 = new uint256[](3);
        uint256[] memory arr2 = new uint256[](8);
        arr1[0] = 1;
        arr1[1] = 2;
        arr1[2] = 3;
        arr2[0] = 4;
        arr2[1] = 5;
        arr2[2] = 6;
        uint256[] memory arr3 = voting.mergeArray(arr1, arr2);
        assertEq(arr3.length, 6);
        assertEq(arr3[0], 1);
        assertEq(arr3[1], 2);
        assertEq(arr3[2], 3);
        assertEq(arr3[3], 4);
        assertEq(arr3[4], 5);
        assertEq(arr3[5], 6);
    }

    function test_RevertStr() public view {
        string memory str = voting.revertStr("ancd");
        assertEq(str, "dcna");
    }

    function test_SearchBinary() public view {
        uint256[] memory arr = new uint256[](5);
        arr[0] = 1;
        arr[1] = 2;
        arr[2] = 3;
        arr[3] = 4;
        arr[4] = 5;
        int256 index = voting.searchBinary(arr, 3);
        assertEq(index, 2);
    }
}
