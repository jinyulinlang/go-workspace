// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MetaNodeToken} from "../src/MetaNodeToken.sol";

import {MetaNodeStake} from "../src/MetaNodeStake.sol";

contract MetaNodeStakeTest is Test {
    MetaNodeToken internal rewardToken;
    MetaNodeStake internal stake;

    address internal user1;

    uint256 internal constant START_BLOCK = 100;
    uint256 internal constant END_BLOCK = 200;
    uint256 internal constant REWARD_PER_BLOCK = 1 ether;
    uint256 internal constant LOCKED_BLOCKS = 10;
    uint256 internal constant MIN_DEPOSIT = 1 ether;

    function setUp() public {
        user1 = makeAddr("user1");
        rewardToken = new MetaNodeToken();
        vm.roll(START_BLOCK);
        MetaNodeStake implementation = new MetaNodeStake();
        bytes memory initData = abi.encodeCall(
            MetaNodeStake.initialize,
            (
                IERC20(address(rewardToken)),
                START_BLOCK,
                END_BLOCK,
                REWARD_PER_BLOCK
            )
        );
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        stake = MetaNodeStake(address(proxy));
        // 第一个池必须是eth池
        stake.addPool(address(0), 100, MIN_DEPOSIT, LOCKED_BLOCKS, false);
    }
    function test_InitializeSetsExpectedValues() public view {
        assertEq(address(stake.MetaNode()), address(rewardToken));
        assertEq(stake.startBlock(), START_BLOCK);
        assertEq(stake.endBlock(), END_BLOCK);
        assertEq(stake.MetaNodePerBlock(), REWARD_PER_BLOCK);
        assertEq(stake.poolLength(), 1);
        // assertTrue(stake.hasRole(stake.ADMIN_ROLE(), address(this)));
    }

    function test_InitializeAllowsEqualStartAndEndBlocks() public {
        MetaNodeStake implementation = new MetaNodeStake();
        bytes memory initData = abi.encodeCall(
            MetaNodeStake.initialize,
            (
                IERC20(address(rewardToken)),
                START_BLOCK,
                START_BLOCK,
                REWARD_PER_BLOCK
            )
        );
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        MetaNodeStake equalRangeStake = MetaNodeStake(address(proxy));
        assertEq(equalRangeStake.startBlock(), START_BLOCK);
        assertEq(equalRangeStake.endBlock(), START_BLOCK);
    }

    function test_InitializeRejectsInvalidBlockRange() public {
        MetaNodeStake implementation = new MetaNodeStake();
        bytes memory initData = abi.encodeCall(
            MetaNodeStake.initialize,
            (
                IERC20(address(rewardToken)),
                END_BLOCK,
                START_BLOCK,
                REWARD_PER_BLOCK
            )
        );
        vm.expectRevert(_error("invalid params"));
        new ERC1967Proxy(address(implementation), initData);
    }

    function test_InitializeCannotBeCalledTwice() public {
        vm.expectRevert();
        stake.initialize(
            IERC20(address(rewardToken)),
            START_BLOCK,
            END_BLOCK,
            REWARD_PER_BLOCK
        );
    }
    function test_NonAdminCannotChangeRewardRate() public {
        vm.expectRevert();
        vm.prank(user1);
        stake.setMetaNodePerBlock(2 ether);
    }
    function test_AdminCannotSetRewardRateToZero() public {
        vm.expectRevert(_error("invalid MetaNodePerBlock"));
        stake.setMetaNodePerBlock(0);
    }

    function test_BlockRangeSettersAllowEqualBoundaries() public {
        stake.setStartBlock(END_BLOCK);
        stake.setEndBlock(END_BLOCK);
        assertEq(stake.startBlock(), END_BLOCK);
        assertEq(stake.endBlock(), END_BLOCK);
    }

    function test_ETHDepositUpdatesUserBalance() public {
        vm.deal(user1, 2 ether);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();
        assertEq(stake.stakingBalance(0, user1), MIN_DEPOSIT);
        assertEq(address(stake).balance, MIN_DEPOSIT);
    }

    function test_ETHDepositRejectsAmountBelowMinimum() public {
        vm.deal(user1, MIN_DEPOSIT);
        vm.expectRevert(_error("deposit amount is too small"));
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT - 1}();
    }

    function test_PendingRewardAccruesPerBlock() public {
        vm.deal(user1, MIN_DEPOSIT);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();
        vm.roll(START_BLOCK + 10);
        assertEq(stake.pendingMetaNode(0, user1), 10 * REWARD_PER_BLOCK);
    }

    function test_ClaimTransfersPendingReward() public {
        vm.deal(user1, MIN_DEPOSIT);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();
        uint256 reward = 5 * REWARD_PER_BLOCK;
        assertTrue(rewardToken.transfer(address(stake), reward));
        vm.roll(START_BLOCK + 5);
        vm.prank(user1);
        stake.claim(0);
        assertEq(rewardToken.balanceOf(user1), reward);
        assertEq(stake.pendingMetaNode(0, user1), 0);
    }

    function test_ETHUnstakeCanBeWithdrawnAfterLock() public {
        vm.deal(user1, 2 ether);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();
        vm.prank(user1);
        stake.unstake(0, MIN_DEPOSIT);

        (uint256 requested, uint256 unlocked) = stake.withdrawAmount(0, user1);
        assertEq(requested, MIN_DEPOSIT);
        assertEq(unlocked, 0);
        assertEq(stake.stakingBalance(0, user1), 0);
        
        vm.roll(block.number + LOCKED_BLOCKS - 1);
        vm.prank(user1);
        stake.withdraw(0);
        assertEq(user1.balance, 1 ether);

        vm.roll(block.number + 1);
        (requested, unlocked) = stake.withdrawAmount(0, user1);
        assertEq(requested, MIN_DEPOSIT);
        assertEq(unlocked, MIN_DEPOSIT);
        vm.prank(user1);
        stake.withdraw(0);

        assertEq(user1.balance, 2 ether);
        (requested, unlocked) = stake.withdrawAmount(0, user1);
        assertEq(requested, 0);
        assertEq(unlocked, 0);
    }

    function test_ERC20DepositTransfersTokens() public {
        MetaNodeToken stakingToken = _addERC20Pool();
        uint256 amount = 2 ether;
        assertTrue(stakingToken.transfer(user1, amount));

        vm.startPrank(user1);
        stakingToken.approve(address(stake), amount);
        stake.deposit(1, amount);
        vm.stopPrank();

        assertEq(stake.stakingBalance(1, user1), amount);
        assertEq(stakingToken.balanceOf(address(stake)), amount);
    }

    function test_ERC20DepositRequiresApproval() public {
        MetaNodeToken stakingToken = _addERC20Pool();
        uint256 amount = 2 ether;

        assertTrue(stakingToken.transfer(user1, amount));

        vm.expectRevert();
        vm.prank(user1);
        stake.deposit(1, amount);
    }

    function test_ERC20DepositRequiresMoreThanMinimum() public {
        MetaNodeToken stakingToken = _addERC20Pool();
        assertTrue(stakingToken.transfer(user1, MIN_DEPOSIT));

        vm.expectRevert(_error("deposit amount is too small"));
        vm.prank(user1);
        stake.deposit(1, MIN_DEPOSIT);
    }
    function test_ERC20UnstakeCanBeWithdrawnAfterLock() public {
        MetaNodeToken stakingToken = _addERC20Pool();
        uint256 amount = 2 ether;
        assertTrue(stakingToken.transfer(user1, amount));
        vm.startPrank(user1);
        stakingToken.approve(address(stake), amount);
        stake.deposit(1, amount);
        stake.unstake(1, amount);
        vm.stopPrank();

        vm.roll(block.number + LOCKED_BLOCKS);
        vm.prank(user1);
        stake.withdraw(1);

        assertEq(stakingToken.balanceOf(user1), amount);
        assertEq(stakingToken.balanceOf(address(stake)), 0);
    }

    function test_GlobalPauseBlocksDepositUntilUnpaused() public {
        vm.deal(user1, MIN_DEPOSIT);
        stake.pause();
        assertTrue(stake.paused());

        vm.expectRevert();
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();
        stake.unpause();
        assertFalse(stake.paused());
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();
        assertEq(stake.stakingBalance(0, user1), MIN_DEPOSIT);
    }
    function test_NonAdminCannotPauseGlobally() public {
        vm.expectRevert();
        vm.prank(user1);
        stake.pause();
    }

    function test_WithdrawPauseBlocksUnstakeButNotDeposit() public {
        vm.deal(user1, 2 ether);
        stake.pauseWithdraw();
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();

        vm.expectRevert(_error("withdraw paused"));
        vm.prank(user1);
        stake.unstake(0, MIN_DEPOSIT);
        stake.unpauseWithdraw();
        vm.prank(user1);
        stake.unstake(0, MIN_DEPOSIT);
    }
    function test_ClaimPauseBlocksClaimUntilUnpaused() public {
        vm.deal(user1, MIN_DEPOSIT);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();

        assertTrue(rewardToken.transfer(address(stake), 2 * REWARD_PER_BLOCK));
        vm.roll(START_BLOCK + 2);
        stake.pauseClaim();

        vm.expectRevert(_error("claim paused"));
        vm.prank(user1);
        stake.claim(0);

        stake.unpauseClaim();
        vm.prank(user1);
        stake.claim(0);
        assertEq(rewardToken.balanceOf(user1), 2 * REWARD_PER_BLOCK);
    }

    function _error(string memory reason) internal pure returns (bytes memory) {
        return abi.encodeWithSignature("Error(string)", reason);
    }

    function _addERC20Pool() internal returns (MetaNodeToken stakingToken) {
        stakingToken = new MetaNodeToken();
        stake.addPool(
            address(stakingToken),
            100,
            MIN_DEPOSIT,
            LOCKED_BLOCKS,
            false
        );
    }
}
