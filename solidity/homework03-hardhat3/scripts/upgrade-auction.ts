import { upgrades } from "@openzeppelin/hardhat-upgrades";
import hre from "hardhat";


async function main() {
  const connection = await hre.network.create();
  const { ethers } = connection;
  const upgradesApi = await upgrades(hre, connection);
  // 替换为实际部署时得到的代理地址
  const PROXY_ADDRESS = "0x9fE46736679d2d9a65F0992F2272dE9f3c7fa6e0";
  console.log("Upgrading NFTAuctionWithOracleSupportUUPSV2... proxy address:", PROXY_ADDRESS);
  const NFTAuctionV2 = await ethers.getContractFactory("NFTAuctionWithOracleSupportUUPSV2");
  const upgrade = await upgradesApi.upgradeProxy(PROXY_ADDRESS, NFTAuctionV2, {
    kind: "uups",
  });
  await upgrade.waitForDeployment();
  const proxyAddress = await upgrade.getAddress();
  console.log("NFTAuctionWithOracleSupportUUPSV2 upgraded to:", proxyAddress);



}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
})