// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {NFTAuctionWithOracle} from "../src/NFTAuctionWithOracle.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract NFTAuctionWithOracleScript is Script {
    function run() public {
        // 从环境变量里面读取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ethUsdFeed = vm.envAddress("ETH_USD_FEED"); // 从环境变量读地址
        address deployer = vm.addr(deployerPrivateKey);
        // 输出部署新息
        console.log("Deploying from:", deployer);
        console.log("Balance:", deployer.balance);
        //开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        //部署合约
        NFTAuctionWithOracle vault = new NFTAuctionWithOracle(
            deployer,
            ethUsdFeed
        );

        //结束广播交易
        vm.stopBroadcast();
        // 输出部署地址
        console.log("NFTAuctionWithOracle deployed at:", address(vault));
    }
}
