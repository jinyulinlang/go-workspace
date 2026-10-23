// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract BeggingContract {
    /// 一个 mapping 来记录每个捐赠者的捐赠金额。
    mapping(address => uint256) public contributers;
    event Contributed(address contributer, uint256 amount);
    uint private totalBalance;
    address private immutable owner;
    constructor() {
        owner = msg.sender;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can withdraw.");
        _;
    }
    /// 一个 donate 函数，允许用户向合约发送以太币，并记录捐赠信息。
    function donate() external payable {
        require(
            msg.value > 0.1 ether,
            "the donate value must be greater than 0.1 ether"
        );
        // 一个 donate 函数，允许用户向合约发送以太币，并记录捐赠信息。
        contributers[msg.sender] += msg.value;
        totalBalance += msg.value;
        emit Contributed(msg.sender, msg.value);
    }

    function withdraw() external payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: totalBalance}("");
        require(success, "Withdrawal failed.");
    }

    function getDonation(address contributer) external view returns (uint256) {
        return contributers[contributer];
    }
}
