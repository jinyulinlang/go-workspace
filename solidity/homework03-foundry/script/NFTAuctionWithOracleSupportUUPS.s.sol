// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {NFTAuctionWithOracleSupportUUPS} from "../src/NFTAuctionWithOracleSupportUUPS.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTAuctionWithOracleSupportUUPSScript is Script {
    function run() public {
        // 从环境变量里面读取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address ethUsdFeed = vm.envAddress("ETH_USD_FEED");
        // 输出部署新息
        console.log("Deploying from:", deployer);
        console.log("Balance:", deployer.balance);
        //开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        //1.部署实现合约
        NFTAuctionWithOracleSupportUUPS implementation = new NFTAuctionWithOracleSupportUUPS();
        //2.编码初始化调用
        bytes memory initData = abi.encodeCall(
            NFTAuctionWithOracleSupportUUPS.initialize,
            (deployer, ethUsdFeed)
        );
        // 3. 部署代理，并在代理构造时执行 initialize
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        //结束广播交易
        vm.stopBroadcast();
        // 输出部署地址
        console.log(
            "NFTAuctionWithOracleSupportUUPS deployed at:",
            address(implementation)
        );
        console.log("Proxy deployed at:", address(proxy));
    }
}
