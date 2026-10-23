import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.create();
const [owner, contributor, outsider] = await ethers.getSigners();

const goal = ethers.parseEther("10");
const contribution = ethers.parseEther("1");

async function deployCampaign(
  campaignOwner = owner.address,
  name = "Community campaign",
  target = goal,
  durationInDays = 1n,
) {
  return ethers.deployContract("CrowdFundingCampaign", [
    campaignOwner,
    name,
    target,
    durationInDays,
  ]);
}

async function moveTo(timestamp: bigint) {
  await ethers.provider.send("evm_setNextBlockTimestamp", [Number(timestamp)]);
  await ethers.provider.send("evm_mine", []);
}

async function deployRejectingActor() {
  const actor = await ethers.deployContract("RevertingCampaignActor", [
    "Rejecting campaign",
    goal,
    1n,
  ]);
  const campaign = await ethers.getContractAt(
    "CrowdFundingCampaign",
    await actor.campaign(),
  );
  return { actor, campaign };
}

describe("CrowdFundingCampaign", function () {
  describe("constructor", function () {
    it("initializes the campaign", async function () {
      const campaign = await deployCampaign();

      expect(await campaign.owner()).to.equal(owner.address);
      expect(await campaign.name()).to.equal("Community campaign");
      expect(await campaign.goal()).to.equal(goal);
      expect(await campaign.deadline()).to.be.greaterThan(0n);
      expect(await campaign.status()).to.equal(0n);
      expect(await campaign.totalRaised()).to.equal(0n);
    });

    it("rejects a zero owner", async function () {
      await expect(deployCampaign(ethers.ZeroAddress)).to.be.revertedWith(
        "CrowdFundingCampaign:Invalid owner",
      );
    });

    it("rejects an empty name", async function () {
      await expect(deployCampaign(owner.address, "")).to.be.revertedWith(
        "CrowdFundingCampaign:Invalid name",
      );
    });

    it("rejects a zero goal", async function () {
      await expect(
        deployCampaign(owner.address, "Campaign", 0n),
      ).to.be.revertedWith("CrowdFundingCampaign:Invalid goal");
    });

    it("rejects a zero duration", async function () {
      await expect(
        deployCampaign(owner.address, "Campaign", goal, 0n),
      ).to.be.revertedWith("CrowdFundingCampaign:Invalid duration");
    });

    it("rejects durations longer than 90 days", async function () {
      await expect(
        deployCampaign(owner.address, "Campaign", goal, 91n),
      ).to.be.revertedWith("CrowdFundingCampaign:Invalid duration");
    });
  });

  describe("start", function () {
    it("allows only the owner to start once", async function () {
      const campaign = await deployCampaign();

      await expect(campaign.connect(outsider).start()).to.be.revertedWith(
        "CrowdFundingCampaign:not owner",
      );
      await expect(campaign.start())
        .to.emit(campaign, "StatusChanged")
        .withArgs(0n, 1n);
      expect(await campaign.status()).to.equal(1n);
      expect(await campaign.isActive()).to.equal(true);
      await expect(campaign.start()).to.be.revertedWith(
        "CrowdFundingCampaign:Invalid status",
      );
    });
  });

  describe("contribute", function () {
    it("requires an active campaign, a positive amount, and an unexpired deadline", async function () {
      const campaign = await deployCampaign();

      await expect(
        campaign.connect(contributor).contribute({ value: contribution }),
      ).to.be.revertedWith("CrowdFundingCampaign:Invalid status");

      await campaign.start();
      await expect(
        campaign.connect(contributor).contribute({ value: 0n }),
      ).to.be.revertedWith("CrowdFundingCampaign:Invalid amount");

      await moveTo(await campaign.deadline());
      await expect(
        campaign.connect(contributor).contribute({ value: contribution }),
      ).to.be.revertedWith("CrowdFundingCampaign:Expired");
    });

    it("tracks first and repeat contributions and marks the campaign successful at its goal", async function () {
      const campaign = await deployCampaign();
      const initialAmount = ethers.parseEther("3");
      const finalAmount = ethers.parseEther("8");

      await campaign.start();
      await expect(
        campaign.connect(contributor).contribute({ value: initialAmount }),
      )
        .to.emit(campaign, "Contribution")
        .withArgs(contributor.address, initialAmount);
      await campaign.connect(contributor).contribute({ value: finalAmount });

      expect(await campaign.contributions(contributor.address)).to.equal(
        initialAmount + finalAmount,
      );
      expect(await campaign.getContributions(contributor.address)).to.equal(
        initialAmount + finalAmount,
      );
      expect(await campaign.totalRaised()).to.equal(goal + contribution);
      expect(await campaign.getContributorCount()).to.equal(1n);
      expect(await campaign.getContributors()).to.deep.equal([
        contributor.address,
      ]);
      expect(await campaign.getProgress()).to.equal(100n);
      expect(await campaign.status()).to.equal(2n);
      expect(await campaign.isActive()).to.equal(false);

      await expect(
        campaign.connect(outsider).contribute({ value: contribution }),
      ).to.be.revertedWith("CrowdFundingCampaign:Invalid status");
    });

    it("caps progress at 100 percent when contributions exceed the goal", async function () {
      const campaign = await deployCampaign();
      await campaign.start();
      await campaign
        .connect(contributor)
        .contribute({ value: ethers.parseEther("12") });

      expect(await campaign.getProgress()).to.equal(100n);
    });
  });

  describe("finalize", function () {
    it("can only finalize an active campaign after its deadline", async function () {
      const campaign = await deployCampaign();

      await expect(campaign.finalize()).to.be.revertedWith(
        "CrowdFundingCampaign:Invalid status",
      );
      await campaign.start();
      await expect(campaign.finalize()).to.be.revertedWith(
        "CrowdFundingCampaign:Not expired",
      );

      await moveTo(await campaign.deadline());
      await expect(campaign.connect(outsider).finalize())
        .to.emit(campaign, "StatusChanged")
        .withArgs(1n, 3n);
      expect(await campaign.status()).to.equal(3n);
      await expect(campaign.finalize()).to.be.revertedWith(
        "CrowdFundingCampaign:Invalid status",
      );
    });
  });

  describe("withdraw", function () {
    it("allows the owner to withdraw a successful campaign once", async function () {
      const campaign = await deployCampaign();
      await campaign.start();
      await campaign
        .connect(contributor)
        .contribute({ value: goal });

      await expect(campaign.connect(outsider).withdraw()).to.be.revertedWith(
        "CrowdFundingCampaign:not owner",
      );
      await expect(campaign.withdraw())
        .to.emit(campaign, "Withdraw")
        .withArgs(owner.address, goal);
      expect(await campaign.status()).to.equal(4n);
      expect(await ethers.provider.getBalance(await campaign.getAddress())).to.equal(
        0n,
      );
      await expect(campaign.withdraw()).to.be.revertedWith(
        "CrowdFundingCampaign:Invalid status",
      );
    });

    it("rejects withdrawals outside the successful state", async function () {
      const campaign = await deployCampaign();
      await expect(campaign.withdraw()).to.be.revertedWith(
        "CrowdFundingCampaign:Invalid status",
      );
    });

    it("rolls back when the owner cannot receive the funds", async function () {
      const { actor, campaign } = await deployRejectingActor();
      await actor.startCampaign();
      await campaign.connect(contributor).contribute({ value: goal });

      await expect(actor.withdrawCampaign()).to.be.revertedWith(
        "CrowdFundingCampaign:Failed to transfer funds",
      );
      expect(await campaign.status()).to.equal(2n);
      expect(await ethers.provider.getBalance(await campaign.getAddress())).to.equal(
        goal,
      );
    });
  });

  describe("refund", function () {
    it("rejects refunds outside the failed state and without a contribution", async function () {
      const campaign = await deployCampaign();
      await expect(campaign.connect(contributor).refund()).to.be.revertedWith(
        "CrowdFundingCampaign:Invalid status",
      );

      await campaign.start();
      await moveTo(await campaign.deadline());
      await campaign.finalize();
      await expect(campaign.connect(contributor).refund()).to.be.revertedWith(
        "CrowdFundingCampaign:No balance",
      );
    });

    it("returns a contributor's funds and updates accounting", async function () {
      const campaign = await deployCampaign();
      await campaign.start();
      await campaign.connect(contributor).contribute({ value: contribution });
      await moveTo(await campaign.deadline());
      await campaign.finalize();

      await expect(campaign.connect(contributor).refund())
        .to.emit(campaign, "Refund")
        .withArgs(contributor.address, contribution);
      expect(await campaign.contributions(contributor.address)).to.equal(0n);
      expect(await campaign.totalRaised()).to.equal(0n);
      expect(await campaign.getContributorCount()).to.equal(1n);
    });

    it("rolls back when a contributor cannot receive the refund", async function () {
      const { actor, campaign } = await deployRejectingActor();
      await actor.startCampaign();
      await actor.contributeToCampaign({ value: contribution });
      await moveTo(await campaign.deadline());
      await campaign.finalize();

      await expect(actor.refundFromCampaign()).to.be.revertedWith(
        "CrowdFundingCampaign:Failed to transfer funds",
      );
      expect(await campaign.contributions(await actor.getAddress())).to.equal(
        contribution,
      );
      expect(await campaign.totalRaised()).to.equal(contribution);
    });
  });
});
