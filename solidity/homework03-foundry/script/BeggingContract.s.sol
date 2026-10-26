// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {BeggingContract} from "../src/BeggingContract.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract BeggingContractScript is Script {
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
        BeggingContract vault = new BeggingContract();

        //结束广播交易
        vm.stopBroadcast();
        // 输出部署地址
        console.log("TokenVault deployed at:", address(vault));
    }
}
