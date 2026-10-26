import hardhatUpgrades from '@openzeppelin/hardhat-upgrades';
import { defineConfig } from "hardhat/config";
export default defineConfig({
  plugins: [
    hardhatUpgrades
  ],
  solidity: {
    version: "0.8.34",
  },
});
