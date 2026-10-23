import { buildModule } from "@nomicfoundation/ignition-core";

export default buildModule("CrowdFundingModule", (m) => {
  const factory = m.contract("CrowdFundingFactory");
  return { factory };
});