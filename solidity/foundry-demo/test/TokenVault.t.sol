// SPDX-LIcense-Identifier: MIT
pragma solidity ^0.8.24;

// 创建一个简单的ERC20代币 用于测试
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {TokenVault} from "../src/TokenVault.sol";
import {Test} from "forge-std/Test.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract TokenVaultTest is Test {
    TokenVault public vault;
    MockERC20 public token;

    // 创建2个用户
    address user1 = address(0x1);
    address user2 = address(0x2);

    // 声明事件以便测试
    event Deposit(
        address indexed sender,
        address indexed token,
        uint256 amount
    );
    // 设置测试环境
    function setUp() public {
        // 创建一个vault
        vault = new TokenVault();

        // 创建一个ERC20代币
        token = new MockERC20("Test Token", "TEST");

        // 将代币分配给用户
        token.mint(user1, 1000 * 10 ** 18);
        token.mint(user2, 1000 * 10 ** 18);
    }
    // 测试存款功能
    function testDeposit() public {
        uint256 amount = 100 * 10 ** 18;
        // 切换到user1 并授权代币
        vm.startPrank(user1);
        token.approve(address(vault), amount);
        // uer1 存款
        vault.deposit(address(token), amount);
        vm.stopPrank();
        // 验证余额
        assertEq(token.balanceOf(address(vault)), amount);
        assertEq(token.balanceOf(user1), 900 * 10 ** 18);
    }
    // 测试提取功能
    function testWithDraw() public {
        uint256 depositAmount = 100 * 10 ** 18;
        uint256 withdrawAmount = 50 * 10 ** 18;

        // 先存款
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount);
        vm.stopPrank();

        // 再提取
        vm.prank(user1);
        vault.withdraw(address(token), withdrawAmount);

        // 验证余额
        assertEq(
            vault.getBalance(user1, address(token)),
            depositAmount - withdrawAmount
        );
        assertEq(token.balanceOf(user1), 950 * 10 ** 18);

        assertEq(token.balanceOf(address(vault)), 50 * 10 ** 18);
    }
    // 测试提取超过余额应该失败
    function testWithDrawInsuuficientBalance() public {
        uint256 depositAmount = 100 * 10 ** 18;
        uint256 withdrawAmount = 200 * 10 ** 18;

        // 先存款
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount);
        vm.stopPrank();

        // 再提取
        vm.prank(user1);
        vm.expectRevert("TokenVault: Insufficient balance");
        vault.withdraw(address(token), withdrawAmount);
    }
    // 测试多个用户
    function testMultipleUsers() public {
        uint256 user1Deposit = 100 * 10 ** 18;
        uint256 user2Deposit = 200 * 10 ** 18;

        // user1 存款
        vm.startPrank(user1);
        token.approve(address(vault), user1Deposit);
        vault.deposit(address(token), user1Deposit);
        vm.stopPrank();

        // user2 存款
        vm.startPrank(user2);
        token.approve(address(vault), user2Deposit);
        vault.deposit(address(token), user2Deposit);
        vm.stopPrank();

        // 验证余额
        assertEq(vault.getBalance(user1, address(token)), user1Deposit);
        assertEq(vault.getBalance(user2, address(token)), user2Deposit);
        // 验证总余额
        assertEq(token.balanceOf(address(vault)), user1Deposit + user2Deposit);
    }
    //  测试存款事件
    function testDepositEvent() public {
        uint256 amount = 100 * 10 ** 18;
        // 切换到user1 并授权代币
        vm.startPrank(user1);
        token.approve(address(vault), amount);

        // 期望触发Deposit事件
        vm.expectEmit(true, true, false, false);
        emit Deposit(user1, address(token), amount);
        // uer1 存款
        vault.deposit(address(token), amount);
        vm.stopPrank();
    }
}
