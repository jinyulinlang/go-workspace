// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MetaNodeStake} from "../src/MetaNodeStake.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MetaNodeStakeScript is Script {
    using SafeERC20 for IERC20;
    function run() public {
        //  从环境变量里面读取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 startBlock = vm.envUint("START_BLOCKS");
        uint256 endBlock = vm.envUint("END_BLOCKS");
        uint256 metaNodePerBlock = vm.envUint("META_NODE_PER_BLOCK");
        address metaNodeToken = vm.envAddress("META_NODE_TOKEN");

        uint256 ethPoolWeight = vm.envUint("ETH_POOL_WEIGHT");
        uint256 ethMinDeposit = vm.envUint("ETH_MIN_DEPOSIT");
        uint256 unstakeLockedBlocks = vm.envUint("UNSTAKE_LOCKED_BLOCKS");
        uint256 initialRewardFunding = vm.envOr(
            "INITIAL_REWARD_FUNDING",
            uint256(0)
        );
        require(startBlock <= endBlock, "invalid block range");
        require(endBlock > block.number, "end block must be in the future");
        require(metaNodePerBlock > 0, "reward rate must be positive");
        require(metaNodeToken.code.length > 0, "token address has no code");
        require(ethPoolWeight > 0, "pool weight must be positive");
        require(unstakeLockedBlocks > 0, "lock period must be positive");

        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deploying from:", deployer);
        console.log("Balance:", deployer.balance);
        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 1.部署实现合约
        MetaNodeStake implementation = new MetaNodeStake();

        // 2.编码初始化调用
        bytes memory initData = abi.encodeCall(
            MetaNodeStake.initialize,
            (IERC20(metaNodeToken), startBlock, endBlock, metaNodePerBlock)
        );
        // 3. 部署代理,并在代理构造时执行 initialize
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        MetaNodeStake stakeProxy = MetaNodeStake(address(proxy));

        stakeProxy.addPool(
            address(0),
            ethPoolWeight,
            ethMinDeposit,
            unstakeLockedBlocks,
            false
        );
        if (initialRewardFunding > 0) {
            IERC20(metaNodeToken).safeTransfer(
                address(proxy),
                initialRewardFunding
            );
        }

        // 4. 结束广播交易
        vm.stopBroadcast();
        // 输出部分地址
        console.log("Implementation deployed at:", address(implementation));
        console.log("Stake Proxy deployed at:", address(proxy));
        console.log("MetaNode token:", metaNodeToken);
        console.log("Initial reward funding:", initialRewardFunding);
    }
}
