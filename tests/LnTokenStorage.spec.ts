import { expect, use } from "chai";
import { Contract } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";

import LnTokenStorage from "../build/development/LnTokenStorage.json";

use(solidity);

describe("LnTokenStorage", () => {
  // Chain spawned outside of `beforeEach` as we're not testing time-dependent cases.
  const provider = new MockProvider({
    ganacheOptions: {
      time: new Date(2020, 0, 1),
    },
  });
  const [developer, alice, bob, charlie, david] = provider.getWallets();

  let lnTokenStorage: Contract;

  beforeEach(async () => {
    lnTokenStorage = await deployContract(developer, LnTokenStorage, [
      alice.address,
      bob.address,
    ]);
  });

  it("only operator can write", async () => {
    await expect(
      lnTokenStorage
        .connect(alice)
        .setAllowance(charlie.address, david.address, 100)
    ).to.revertedWith("Only operator can perform this action");

    await expect(
      lnTokenStorage.connect(alice).setBalanceOf(charlie.address, 100)
    ).to.revertedWith("Only operator can perform this action");

    await lnTokenStorage
      .connect(bob)
      .setAllowance(charlie.address, david.address, 100);

    await lnTokenStorage.connect(bob).setBalanceOf(charlie.address, 100);
  });

  it("balance should update after setBalanceOf", async () => {
    expect(await lnTokenStorage.balanceOf(charlie.address)).to.equal(0);

    await lnTokenStorage.connect(bob).setBalanceOf(charlie.address, 100);

    expect(await lnTokenStorage.balanceOf(charlie.address)).to.equal(100);
  });

  it("allowance should update after setAllowance", async () => {
    expect(
      await lnTokenStorage.allowance(charlie.address, david.address)
    ).to.equal(0);

    await lnTokenStorage
      .connect(bob)
      .setAllowance(charlie.address, david.address, 100);

    expect(
      await lnTokenStorage.allowance(charlie.address, david.address)
    ).to.equal(100);
  });
});
