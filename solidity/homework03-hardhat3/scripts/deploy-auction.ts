import { upgrades } from "@openzeppelin/hardhat-upgrades";
import hre from "hardhat";

async function main() {
  const connection = await hre.network.create();
  const { ethers } = connection;
  const upgradesApi = await upgrades(hre, connection);
  const NFTAuction = await ethers.getContractFactory("NFTAuctionWithOracleSupportUUPS");
  const deployer = (await ethers.getSigners())[0];
  // Sepolia ETH/USD 喂价地址（主网或其他网络需替换）
  const ETH_USD_FEED = "0x5f4eC3Df9cbd43714FE2740b5E3616155c5b8419";

  console.log("Deploying NFTAuctionWithOracleSupportUUPS...");
  const auction = await upgradesApi.deployProxy(NFTAuction, [deployer.address, ETH_USD_FEED], {
    kind: "uups",
  });
  await auction.waitForDeployment();
  const proxyAddress = await auction.getAddress();
  console.log("NFTAuctionWithOracleSupportUUPS deployed to:", proxyAddress);
  console.log("please keep the proxy address for later use");
  



}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
})