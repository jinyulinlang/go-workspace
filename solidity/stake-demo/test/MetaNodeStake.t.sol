// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MetaNodeToken} from "../src/MetaNodeToken.sol";

import {MetaNodeStake} from "../src/MetaNodeStake.sol";

contract ETHWithdrawReceiver {
    MetaNodeStake internal immutable stake;
    uint8 internal transferMode;

    constructor(MetaNodeStake _stake) {
        stake = _stake;
    }

    function depositStake() external payable {
        stake.depositETH{value: msg.value}();
    }

    function requestUnstake(uint256 amount) external {
        stake.unstake(0, amount);
    }

    function withdrawStake() external {
        stake.withdraw(0);
    }

    function setTransferMode(uint8 mode) external {
        transferMode = mode;
    }

    receive() external payable {
        if (transferMode == 2) {
            revert();
        }

        bool accepted = transferMode == 1;
        assembly {
            mstore(0, accepted)
            return(0, 32)
        }
    }
}

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
            MetaNodeStake.initialize, (IERC20(address(rewardToken)), START_BLOCK, END_BLOCK, REWARD_PER_BLOCK)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
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
            MetaNodeStake.initialize, (IERC20(address(rewardToken)), START_BLOCK, START_BLOCK, REWARD_PER_BLOCK)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        MetaNodeStake equalRangeStake = MetaNodeStake(address(proxy));
        assertEq(equalRangeStake.startBlock(), START_BLOCK);
        assertEq(equalRangeStake.endBlock(), START_BLOCK);
    }

    function test_InitializeRejectsInvalidBlockRange() public {
        MetaNodeStake implementation = new MetaNodeStake();
        bytes memory initData = abi.encodeCall(
            MetaNodeStake.initialize, (IERC20(address(rewardToken)), END_BLOCK, START_BLOCK, REWARD_PER_BLOCK)
        );
        vm.expectRevert(_error("invalid params"));
        new ERC1967Proxy(address(implementation), initData);
    }

    function test_InitializeCannotBeCalledTwice() public {
        vm.expectRevert();
        stake.initialize(IERC20(address(rewardToken)), START_BLOCK, END_BLOCK, REWARD_PER_BLOCK);
    }

    function test_NonAdminCannotChangeMetaNode() public {
        vm.expectRevert();
        vm.prank(user1);
        stake.setMetaNode(IERC20(address(rewardToken)));
    }

    function test_AdminCanChangeMetaNode() public {
        MetaNodeToken replacementToken = new MetaNodeToken();
        stake.setMetaNode(IERC20(address(replacementToken)));

        assertEq(address(stake.MetaNode()), address(replacementToken));
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

    function test_BlockRangeSettersRejectInvalidBoundaries() public {
        vm.expectRevert(_error("invalid start block"));
        stake.setStartBlock(END_BLOCK + 1);

        vm.expectRevert(_error("invalid end block"));
        stake.setEndBlock(START_BLOCK - 1);
    }

    function test_AddPoolRejectsZeroAddressAfterETHPool() public {
        vm.expectRevert(_error("invalid staking token address"));
        stake.addPool(address(0), 100, MIN_DEPOSIT, LOCKED_BLOCKS, false);
    }

    function test_FirstPoolMustUseZeroAddress() public {
        MetaNodeStake unpooledStake = _deployStakeWithoutPool();
        MetaNodeToken stakingToken = new MetaNodeToken();

        vm.expectRevert(_error("invalid staking token address"));
        unpooledStake.addPool(address(stakingToken), 100, MIN_DEPOSIT, LOCKED_BLOCKS, false);
    }

    function test_FirstPoolCanBeAddedAtStartBlock() public {
        MetaNodeStake unpooledStake = _deployStakeWithoutPool();
        unpooledStake.addPool(address(0), 100, MIN_DEPOSIT, LOCKED_BLOCKS, false);

        assertEq(unpooledStake.poolLength(), 1);
    }

    function test_AddPoolRejectsZeroLockPeriod() public {
        MetaNodeToken stakingToken = new MetaNodeToken();
        vm.expectRevert(_error("invalid withdraw locked blocks"));
        stake.addPool(address(stakingToken), 100, MIN_DEPOSIT, 0, false);
    }

    function test_AddPoolRejectsWhenRewardsHaveEnded() public {
        MetaNodeToken stakingToken = new MetaNodeToken();
        vm.roll(END_BLOCK);

        vm.expectRevert(_error("Already ended"));
        stake.addPool(address(stakingToken), 100, MIN_DEPOSIT, LOCKED_BLOCKS, false);
    }

    function test_NonAdminCannotAddPool() public {
        MetaNodeToken stakingToken = new MetaNodeToken();

        vm.expectRevert();
        vm.prank(user1);
        stake.addPool(address(stakingToken), 100, MIN_DEPOSIT, LOCKED_BLOCKS, false);
    }

    function test_AdminCanUpdatePoolAndWeight() public {
        _addERC20Pool();

        stake.updatePool(1, 2 ether, LOCKED_BLOCKS * 2);
        stake.setPoolWeight(1, 200, false);

        (, uint256 poolWeight,,,, uint256 minDepositAmount, uint256 unstakeLockedBlocks) = stake.pools(1);
        assertEq(poolWeight, 200);
        assertEq(minDepositAmount, 2 ether);
        assertEq(unstakeLockedBlocks, LOCKED_BLOCKS * 2);
        assertEq(stake.totalPoolWeight(), 300);
    }

    function test_NonAdminCannotUpdatePool() public {
        vm.expectRevert();
        vm.prank(user1);
        stake.updatePool(0, 2 ether, LOCKED_BLOCKS);
    }

    function test_SetPoolWeightRejectsZero() public {
        vm.expectRevert(_error("invalid pool weight"));
        stake.setPoolWeight(0, 0, false);
    }

    function test_SetPoolWeightWithUpdateSettlesRewardsFirst() public {
        vm.deal(user1, MIN_DEPOSIT);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();
        vm.roll(START_BLOCK + 5);

        stake.setPoolWeight(0, 200, true);

        assertEq(stake.pendingMetaNode(0, user1), 5 * REWARD_PER_BLOCK);
        assertEq(stake.totalPoolWeight(), 200);
    }

    function test_PoolConfigurationRejectsInvalidPoolId() public {
        vm.expectRevert(_error("invalid pool id"));
        stake.updatePool(1, MIN_DEPOSIT, LOCKED_BLOCKS);

        vm.expectRevert(_error("invalid pool id"));
        stake.setPoolWeight(1, 200, false);
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

    function test_ETHDepositOfZeroWhenMinimumIsZeroDoesNotChangeBalance() public {
        stake.updatePool(0, 0, LOCKED_BLOCKS);

        vm.prank(user1);
        stake.depositETH{value: 0}();

        assertEq(stake.stakingBalance(0, user1), 0);
    }

    function test_ERC20DepositRejectsETHPoolAndInvalidPoolId() public {
        vm.expectRevert(_error("deposit not support ETH staking"));
        vm.prank(user1);
        stake.deposit(0, 2 ether);

        vm.expectRevert(_error("invalid pool id"));
        vm.prank(user1);
        stake.deposit(1, 2 ether);
    }

    function test_PendingRewardAccruesPerBlock() public {
        vm.deal(user1, MIN_DEPOSIT);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();
        vm.roll(START_BLOCK + 10);
        assertEq(stake.pendingMetaNode(0, user1), 10 * REWARD_PER_BLOCK);
    }

    function test_SecondDepositPreservesPreviouslyAccruedReward() public {
        vm.deal(user1, 2 * MIN_DEPOSIT);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();
        vm.roll(START_BLOCK + 3);

        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();

        assertEq(stake.stakingBalance(0, user1), 2 * MIN_DEPOSIT);
        assertEq(stake.pendingMetaNode(0, user1), 3 * REWARD_PER_BLOCK);

        vm.roll(START_BLOCK + 5);
        assertEq(stake.pendingMetaNode(0, user1), 5 * REWARD_PER_BLOCK);
    }

    function test_GetMultiplierClampsToRewardSchedule() public view {
        assertEq(stake.getMultiplier(START_BLOCK - 10, END_BLOCK + 10), (END_BLOCK - START_BLOCK) * REWARD_PER_BLOCK);
        assertEq(stake.getMultiplier(START_BLOCK, START_BLOCK), 0);
    }

    function test_GetMultiplierRejectsInvalidBlockRanges() public {
        vm.expectRevert(_error("invalid block"));
        stake.getMultiplier(START_BLOCK + 1, START_BLOCK);

        vm.expectRevert(_error("end block must be greater than start block"));
        stake.getMultiplier(END_BLOCK + 1, END_BLOCK + 2);
    }

    function test_AdminCanUpdateRewardRate() public {
        stake.setMetaNodePerBlock(2 ether);

        assertEq(stake.MetaNodePerBlock(), 2 ether);
    }

    function test_RewardsStopAtEndBlock() public {
        vm.deal(user1, MIN_DEPOSIT);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();
        vm.roll(END_BLOCK + 10);

        assertEq(stake.pendingMetaNode(0, user1), (END_BLOCK - START_BLOCK) * REWARD_PER_BLOCK);
    }

    function test_PendingRewardRemainsVisibleAfterFullUnstake() public {
        vm.deal(user1, MIN_DEPOSIT);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();

        vm.roll(START_BLOCK + 3);
        vm.prank(user1);
        stake.unstake(0, MIN_DEPOSIT);

        assertEq(stake.stakingBalance(0, user1), 0);
        assertEq(stake.pendingMetaNode(0, user1), 3 * REWARD_PER_BLOCK);
    }

    function test_UpdatePoolWithNoStakersDoesNotAccrueRewards() public {
        vm.roll(START_BLOCK + 5);
        stake.updatePool(0);

        assertEq(stake.pendingMetaNode(0, user1), 0);
    }

    function test_MassUpdatePoolsAccruesRewardsForStakedUser() public {
        vm.deal(user1, MIN_DEPOSIT);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();
        vm.roll(START_BLOCK + 5);

        stake.massUpdatePools();

        assertEq(stake.pendingMetaNode(0, user1), 5 * REWARD_PER_BLOCK);
    }

    function test_AddPoolWithUpdateSettlesExistingPoolFirst() public {
        vm.deal(user1, MIN_DEPOSIT);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();
        vm.roll(START_BLOCK + 5);

        MetaNodeToken stakingToken = new MetaNodeToken();
        stake.addPool(address(stakingToken), 100, MIN_DEPOSIT, LOCKED_BLOCKS, true);

        assertEq(stake.pendingMetaNode(0, user1), 5 * REWARD_PER_BLOCK);
        assertEq(stake.poolLength(), 2);
    }

    function test_UpdatePoolReturnsForCurrentBlock() public {
        stake.updatePool(0);

        assertEq(stake.pendingMetaNode(0, user1), 0);
    }

    function test_PendingRewardRejectsInvalidPoolId() public {
        vm.expectRevert(_error("invalid pool id"));
        stake.pendingMetaNode(1, user1);
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

    function test_ClaimWithNoRewardsDoesNotTransferTokens() public {
        vm.prank(user1);
        stake.claim(0);

        assertEq(rewardToken.balanceOf(user1), 0);
    }

    function test_ClaimRejectsInvalidPoolId() public {
        vm.expectRevert(_error("invalid pool id"));
        vm.prank(user1);
        stake.claim(1);
    }

    function test_UnstakeRejectsAmountAboveUserBalance() public {
        vm.expectRevert(_error("Not enough staking tokein balance"));
        vm.prank(user1);
        stake.unstake(0, 1);
    }

    function test_ZeroAmountUnstakeDoesNotCreateWithdrawalRequest() public {
        vm.deal(user1, MIN_DEPOSIT);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();

        vm.prank(user1);
        stake.unstake(0, 0);

        (uint256 requested, uint256 unlocked) = stake.withdrawAmount(0, user1);
        assertEq(requested, 0);
        assertEq(unlocked, 0);
        assertEq(stake.stakingBalance(0, user1), MIN_DEPOSIT);
    }

    function test_WithdrawRejectsInvalidPoolId() public {
        vm.expectRevert(_error("invalid pool id"));
        vm.prank(user1);
        stake.withdraw(1);
    }

    function test_WithdrawHandlesMultipleRequestsWithDifferentUnlockBlocks() public {
        vm.deal(user1, 3 ether);
        vm.prank(user1);
        stake.depositETH{value: 2 ether}();

        vm.prank(user1);
        stake.unstake(0, 1 ether);
        vm.roll(START_BLOCK + 5);
        vm.prank(user1);
        stake.unstake(0, 1 ether);

        vm.roll(START_BLOCK + LOCKED_BLOCKS);
        vm.prank(user1);
        stake.withdraw(0);

        assertEq(user1.balance, 2 ether);
        (uint256 requested, uint256 unlocked) = stake.withdrawAmount(0, user1);
        assertEq(requested, 1 ether);
        assertEq(unlocked, 0);

        vm.roll(START_BLOCK + LOCKED_BLOCKS + 5);
        vm.prank(user1);
        stake.withdraw(0);

        assertEq(user1.balance, 3 ether);
        (requested, unlocked) = stake.withdrawAmount(0, user1);
        assertEq(requested, 0);
        assertEq(unlocked, 0);
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

    function test_ETHWithdrawHandlesReceiverReturnAndRevertPaths() public {
        ETHWithdrawReceiver receiver = new ETHWithdrawReceiver(stake);
        vm.deal(address(this), MIN_DEPOSIT);

        receiver.depositStake{value: MIN_DEPOSIT}();
        receiver.requestUnstake(MIN_DEPOSIT);
        vm.roll(block.number + LOCKED_BLOCKS);

        receiver.setTransferMode(2);
        vm.expectRevert(_error("ETH transfer call failed"));
        receiver.withdrawStake();

        receiver.setTransferMode(0);
        vm.expectRevert(_error("ETH  transfer operation did not succeed"));
        receiver.withdrawStake();

        receiver.setTransferMode(1);
        receiver.withdrawStake();
        assertEq(address(receiver).balance, MIN_DEPOSIT);
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

    function test_GlobalPauseBlocksWithdrawUntilUnpaused() public {
        vm.deal(user1, 2 ether);
        vm.prank(user1);
        stake.depositETH{value: MIN_DEPOSIT}();
        vm.prank(user1);
        stake.unstake(0, MIN_DEPOSIT);
        vm.roll(block.number + LOCKED_BLOCKS);

        stake.pause();
        vm.expectRevert();
        vm.prank(user1);
        stake.withdraw(0);

        stake.unpause();
        vm.prank(user1);
        stake.withdraw(0);
        assertEq(user1.balance, 2 ether);
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

    function test_GlobalPauseCannotBeRepeatedOrUnpausedTwice() public {
        stake.pause();
        vm.expectRevert();
        stake.pause();

        stake.unpause();
        vm.expectRevert();
        stake.unpause();
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

    function test_WithdrawPauseRejectsRepeatedPauseAndUnpause() public {
        stake.pauseWithdraw();
        vm.expectRevert(_error("withdraw paused"));
        stake.pauseWithdraw();

        stake.unpauseWithdraw();
        vm.expectRevert(_error("withdraw not paused"));
        stake.unpauseWithdraw();
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

    function test_ClaimPauseRejectsRepeatedPauseAndUnpause() public {
        stake.pauseClaim();
        vm.expectRevert(_error("claim paused"));
        stake.pauseClaim();

        stake.unpauseClaim();
        vm.expectRevert(_error("claim not paused"));
        stake.unpauseClaim();
    }

    function test_OnlyUpgradeRoleCanUpgradeProxy() public {
        MetaNodeStake nextImplementation = new MetaNodeStake();

        vm.expectRevert();
        vm.prank(user1);
        stake.upgradeToAndCall(address(nextImplementation), bytes(""));

        stake.upgradeToAndCall(address(nextImplementation), bytes(""));
        assertEq(stake.startBlock(), START_BLOCK);
    }

    function _error(string memory reason) internal pure returns (bytes memory) {
        return abi.encodeWithSignature("Error(string)", reason);
    }

    function _deployStakeWithoutPool() internal returns (MetaNodeStake unpooledStake) {
        MetaNodeStake implementation = new MetaNodeStake();
        bytes memory initData = abi.encodeCall(
            MetaNodeStake.initialize, (IERC20(address(rewardToken)), START_BLOCK, END_BLOCK, REWARD_PER_BLOCK)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        unpooledStake = MetaNodeStake(address(proxy));
    }

    function _addERC20Pool() internal returns (MetaNodeToken stakingToken) {
        stakingToken = new MetaNodeToken();
        stake.addPool(address(stakingToken), 100, MIN_DEPOSIT, LOCKED_BLOCKS, false);
    }
}
