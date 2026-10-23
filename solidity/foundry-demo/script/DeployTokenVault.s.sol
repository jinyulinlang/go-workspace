// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {TokenVault} from "../src/TokenVault.sol";

contract DeployTokenVault is Script {
    function run() public {
        // 从环境变量里面读取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        // 输出部署新息
        console.log("Deploying from:", deployer);
        console.log("Balance:", deployer.balance);
        //开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        //部署合约
        TokenVault vault = new TokenVault();

        //结束广播交易
        vm.stopBroadcast();
        // 输出部署地址
        console.log("TokenVault deployed at:", address(vault));
    }
}
