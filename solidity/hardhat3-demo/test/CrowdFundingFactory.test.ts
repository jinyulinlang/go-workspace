import { expect } from "chai";
import type {
  ContractTransactionResponse,
  Interface,
  Signer,
} from "ethers";
import { network } from "hardhat";

const { ethers } = await network.create();
const [owner, secondCreator, other] = await ethers.getSigners();
const goal = ethers.parseEther("5");

type Creator = Signer & { address: string };

type FactoryContract = {
  connect(signer: Signer): FactoryContract;
  createCampaign(
    name: string,
    target: bigint,
    durationInDays: bigint,
  ): Promise<ContractTransactionResponse>;
  getCampaignCount(): Promise<bigint>;
  campaigns(index: bigint): Promise<string>;
  getAllCampaigns(): Promise<string[]>;
  getUserCampaigns(creator: string): Promise<string[]>;
  interface: Interface;
};

async function createAndCheckEvent(
  factory: FactoryContract,
  creator: Creator,
  name: string,
) {
  const receipt = await (
    await factory.connect(creator).createCampaign(name, goal, 7n)
  ).wait();
  const event = receipt?.logs
    .map((log) => {
      try {
        return factory.interface.parseLog(log);
      } catch {
        return null;
      }
    })
    .find((parsed) => parsed?.name === "CampaignCreated");

  expect(event).not.to.equal(undefined);
  expect(event).not.to.equal(null);
  if (!event) {
    throw new Error("CampaignCreated event was not emitted");
  }

  expect(event.args.creator).to.equal(creator.address);
  expect(event.args.name).to.equal(name);
  expect(event.args.goal).to.equal(goal);
  expect(event.args.deadline).to.be.greaterThan(0n);
  return event.args.campaign as string;
}

describe("CrowdFundingFactory", function () {
  it("returns empty results before any campaigns are created", async function () {
    const factory = (await ethers.deployContract(
      "CrowdFundingFactory",
    )) as unknown as FactoryContract;

    expect(await factory.getCampaignCount()).to.equal(0n);
    expect(await factory.getAllCampaigns()).to.deep.equal([]);
    expect(await factory.getUserCampaigns(owner.address)).to.deep.equal([]);
    await expect(
      factory.getUserCampaigns(ethers.ZeroAddress),
    ).to.be.revertedWith("Invalid address");
  });

  it("creates campaigns, emits events, and tracks global and per-user results", async function () {
    const factory = (await ethers.deployContract(
      "CrowdFundingFactory",
    )) as unknown as FactoryContract;

    const firstAddress = await createAndCheckEvent(
      factory,
      owner,
      "Owner campaign one",
    );
    const secondAddress = await createAndCheckEvent(
      factory,
      secondCreator,
      "Second creator campaign",
    );
    const thirdAddress = await createAndCheckEvent(
      factory,
      owner,
      "Owner campaign two",
    );

    expect(await factory.getCampaignCount()).to.equal(3n);
    expect(await factory.campaigns(0n)).to.equal(firstAddress);
    expect(await factory.campaigns(1n)).to.equal(secondAddress);
    expect(await factory.campaigns(2n)).to.equal(thirdAddress);
    expect(await factory.getAllCampaigns()).to.deep.equal([
      firstAddress,
      secondAddress,
      thirdAddress,
    ]);
    expect(await factory.getUserCampaigns(owner.address)).to.deep.equal([
      firstAddress,
      thirdAddress,
    ]);
    expect(
      await factory.getUserCampaigns(secondCreator.address),
    ).to.deep.equal([secondAddress]);
    expect(await factory.getUserCampaigns(other.address)).to.deep.equal([]);

    const firstCampaign = await ethers.getContractAt(
      "CrowdFundingCampaign",
      firstAddress,
    );
    expect(await firstCampaign.owner()).to.equal(owner.address);
    expect(await firstCampaign.name()).to.equal("Owner campaign one");
    expect(await firstCampaign.goal()).to.equal(goal);
  });
});
