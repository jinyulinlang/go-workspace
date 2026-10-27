// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**

1. ✅ 创建一个名为Voting的合约，包含以下功能：
一个mapping来存储候选人的得票数
一个vote函数，允许用户投票给某个候选人
一个getVotes函数，返回某个候选人的得票数
一个resetVotes函数，重置所有候选人的得票数
2. ✅ 反转字符串 (Reverse String)
题目描述：反转一个字符串。输入 "abcde"，输出 "edcba"
3. ✅ 用 solidity 实现整数转罗马数字
题目描述在 https://leetcode.cn/problems/roman-to-integer/description/3.
4. ✅ 用 solidity 实现罗马数字转数整数
题目描述在 https://leetcode.cn/problems/integer-to-roman/description/
5. ✅ 合并两个有序数组 (Merge Sorted Array)
题目描述：将两个有序数组合并为一个有序数组。
6. ✅ 二分查找 (Binary Search)
题目描述：在一个有序数组中查找目标值。
 */

contract Voting {
    /// 一个mapping来存储候选人的得票数
    mapping(address => uint256) public candidateVoteCounts;
    mapping(address => bool) private voters;
    address[] private candidates;

    event UserVoteCandidate(address indexed user, address indexed candidate);
    /**
     *  一个vote函数，允许用户投票给某个候选人
     */
    function vote(address user, address candidate) external {
        // 校验 用户的地址不能是0地址
        require(user != address(0), "user address must be exist");
        // 校验 候选人地址不能是0地址
        require(candidate != address(0), "candidate address must be exist");

        if (voters[user]) {
            revert("you had take part in this votes");
        }
        // 把投票人更改为true
        voters[user] = true;
        if (candidateVoteCounts[candidate] == 0) {
            candidates.push(candidate);
        }
        candidateVoteCounts[candidate] += 1;
        emit UserVoteCandidate(user, candidate);
    }

    /**
    一个getVotes函数，返回某个候选人的得票数
    */
    function getVotes(address candidate) external view returns (uint256) {
        require(candidate != address(0), "candidate address must be exist");
        return candidateVoteCounts[candidate];
    }
    /**
     *  一个resetVotes函数，重置所有候选人的得票数
     */
    function resetVotes() external {
        uint256 length = candidates.length;
        for (uint256 i = 0; i < length; i++) {
            candidateVoteCounts[candidates[i]] = 0;
        }
    }

    /**
      题目描述：反转一个字符串。输入 "abcde"，输出 "edcba"
       */
    function revertStr(
        string memory str
    ) external pure returns (string memory) {
        // 先把字符串转换成字节数组
        bytes memory bts = bytes(str);
        // 获取其长度
        uint256 length = bts.length;
        if (length <= 1) {
            return str;
        }
        // 声明一个反转的字节数组
        bytes memory revertBts = new bytes(length);
        uint256 index = 0;
        for (uint256 i = length; i > 0; i--) {
            revertBts[index] = bts[i - 1];
            index++;
        }
        return string(revertBts);
    }

    /**
      用 solidity 实现罗马数字转数整数
     */
    function romanToInt(string memory value) external pure returns (uint256) {
        uint256 sum = 0;
        uint256 maxSeen = 0;
        bytes memory bts = bytes(value);
        uint256 length = bts.length;
        for (uint256 i = length; i > 0; i--) {
            uint256 cur = _romanMatchInt(bts[i - 1]);
            if (cur < maxSeen) {
                sum -= cur;
            } else {
                sum += cur;
                maxSeen = cur;
            }
        }
        return sum;
    }

    function _romanMatchInt(bytes1 c) private pure returns (uint256) {
        if (c == "I") return 1;
        if (c == "V") return 5;
        if (c == "X") return 10;
        if (c == "L") return 50;
        if (c == "C") return 100;
        if (c == "D") return 500;
        if (c == "M") return 1000;
        return 0;
    }

    /**
      3. ✅ 用 solidity 实现整数转罗马数字
     题目描述在 https://leetcode.cn/problems/roman-to-integer/description/3.
   */
    function intToRoman(uint256 num) external pure returns (string memory) {
        require(num >= 1 && num <= 3999, "num out of range");

        uint256[13] memory values = [
            uint256(1000),
            900,
            500,
            400,
            100,
            90,
            50,
            40,
            10,
            9,
            5,
            4,
            1
        ];

        string[13] memory symbols = [
            "M",
            "CM",
            "D",
            "CD",
            "C",
            "XC",
            "L",
            "XL",
            "X",
            "IX",
            "V",
            "IV",
            "I"
        ];
        bytes memory buffer = new bytes(20);
        uint256 index = 0;
        for (uint256 i = 0; i < 13; i++) {
            while (num >= values[i]) {
                bytes memory sym = bytes(symbols[i]);
                uint256 len = sym.length;
                for (uint256 j = 0; j < len; j++) {
                    buffer[index++] = sym[j];
                }
                num -= values[i];
            }
        }
        return string(_slice(buffer, index));
    }

    function _slice_uint(
        uint256[] memory arr,
        uint256 length
    ) private pure returns (uint256[] memory data) {
        uint256[] memory result = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = arr[i];
        }
        data = result;
    }
    /**

     */
    function _slice(
        bytes memory data,
        uint256 length
    ) private pure returns (bytes memory) {
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = data[i];
        }
        return result;
    }

    /**
     * 将两个有序数组合并为一个有序数组。
     */
    function mergeArray(
        uint256[] memory a,
        uint256[] memory b
    ) external pure returns (uint256[] memory) {
        uint256 alength = a.length;
        uint256 blength = b.length;
        uint256 length = alength + blength;

        uint256[] memory result = new uint256[](length);
        uint256 index = 0;
        for (uint256 i = 0; i < alength; i++) {
            result[i] = a[i];
            index++;
        }
        for (uint256 i = 0; i < blength; i++) {
            result[i + alength] = b[i];
            index++;
        }
        return _slice_uint(result, index);
    }
    /**
     * 在一个有序数组中查找目标值。
     */
    function searchBinary(
        uint256[] memory a,
        uint256 target
    ) external pure returns (int256) {
        uint256 alength = a.length;
        // 使用二分查找
        uint256 left = 0;
        uint256 right = alength - 1;
        while (left <= right) {
            uint256 mid = left + (right - left) / 2;
            if (a[mid] == target) {
                return int256(mid);
            } else if (a[mid] < target) {
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }
        return -1;
    }
}
