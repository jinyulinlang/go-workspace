// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Script} from "forge-std/Script.sol";
import {Voting} from "../src/Voting.sol";
import {console} from "forge-std/console.sol";
contract VotingScript is Script {
    function run() public {
        // 从环境变量里面读取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        // 输出部署新息
        console.log("Deploying from:", deployer);
        console.log("Balance:", deployer.balance);
        vm.startBroadcast(deployer);

        Voting voting = new Voting();

        vm.stopBroadcast();
        console.log("Voting deployed at:", address(voting));
    }
}
