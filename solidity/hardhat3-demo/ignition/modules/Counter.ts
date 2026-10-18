import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
// deploy sepolia address
// https://sepolia.infura.io/v3/f15b139378d94492bd52d609b463c58c
// private key (metamask private key)
// CounterModule#Counter - 0xcAF09360b81ec5b3Acc38b89c6519f3A670633fB
export default buildModule("CounterModule", (m) => {
  const counter = m.contract("Counter");

  m.call(counter, "incBy", [5n]);

  return { counter };
});
