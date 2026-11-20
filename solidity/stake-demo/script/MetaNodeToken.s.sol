// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MetaNodeToken} from "../src/MetaNodeToken.sol";

contract MetaNodeTokenScript is Script {
    function run() public {
        //  从环境变量里面读取私钥
        uint256 deoloyerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deoloyerPrivateKey);
        console.log("Deploying from:", deployer);
        console.log("Balance:", deployer.balance);
        // 开始广播交易
        vm.startBroadcast(deoloyerPrivateKey);

        // 部署合约
        MetaNodeToken mnt = new MetaNodeToken();
        //  结束广播交易
        vm.stopBroadcast();
        // 输出部署地址
        console.log("MetaNodeToken deployed at :", address(mnt));
    }
}
