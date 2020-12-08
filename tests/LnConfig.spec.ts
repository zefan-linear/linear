import { expect, use } from "chai";
import { Contract, ethers } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";

import LnConfig from "../build/development/LnConfig.json";

use(solidity);

describe("LnConfig", () => {
  // Chain spawned outside of `beforeEach` as we're not testing time-dependent cases.
  const provider = new MockProvider({
    ganacheOptions: {
      time: new Date(2020, 0, 1),
    },
  });
  const [developer, alice, bob, charlie, david] = provider.getWallets();

  let lnConfig: Contract;

  beforeEach(async () => {
    lnConfig = await deployContract(developer, LnConfig, [alice.address]);
  });

  it("only admin can set config", async () => {
    await expect(
      lnConfig
        .connect(bob)
        .setUint(ethers.utils.formatBytes32String("test"), 100)
    ).to.revertedWith("Only the contract admin can perform this action");

    await expect(
      lnConfig
        .connect(bob)
        .batchSet([ethers.utils.formatBytes32String("test")], [100])
    ).to.revertedWith("Only the contract admin can perform this action");

    await lnConfig
      .connect(alice)
      .setUint(ethers.utils.formatBytes32String("test"), 100);

    await lnConfig
      .connect(alice)
      .batchSet([ethers.utils.formatBytes32String("test")], [100]);
  });

  it("config value changed after update", async () => {
    expect(
      await lnConfig.getUint(ethers.utils.formatBytes32String("test"))
    ).to.equal(0);

    await lnConfig
      .connect(alice)
      .setUint(ethers.utils.formatBytes32String("test"), 100);

    expect(
      await lnConfig.getUint(ethers.utils.formatBytes32String("test"))
    ).to.equal(100);
  });

  it("config value is zero after deletion", async () => {
    await lnConfig
      .connect(alice)
      .setUint(ethers.utils.formatBytes32String("test"), 100);

    expect(
      await lnConfig.getUint(ethers.utils.formatBytes32String("test"))
    ).to.equal(100);

    await lnConfig
      .connect(alice)
      .deleteUint(ethers.utils.formatBytes32String("test"));

    expect(
      await lnConfig.getUint(ethers.utils.formatBytes32String("test"))
    ).to.equal(0);
  });
});
