import { expect, use } from "chai";
import { Contract, ethers } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";

import LnAccessControl from "../build/development/LnAccessControl.json";
import LnLinearStakingStorage from "../build/development/LnLinearStakingStorage.json";

use(solidity);

describe("LnLinearStakingStorage", () => {
  // Chain spawned outside of `beforeEach` as we're not testing time-dependent cases.
  const provider = new MockProvider({
    ganacheOptions: {
      time: new Date(2020, 0, 1),
    },
  });
  const [developer, alice, bob, charlie, david] = provider.getWallets();

  let lnAccessControl: Contract;
  let lnLinearStakingStorage: Contract;

  beforeEach(async () => {
    lnAccessControl = await deployContract(developer, LnAccessControl, [
      alice.address, // admin
    ]);

    lnLinearStakingStorage = await deployContract(
      developer,
      LnLinearStakingStorage,
      [
        alice.address, // _admin
        lnAccessControl.address, // _accessCtrl
      ]
    );

    // Allows Bob to modify storage
    await lnAccessControl
      .connect(alice)
      .SetRoles(
        ethers.utils.formatBytes32String("LinearStakingStorage"),
        [bob.address],
        [true]
      );
  });

  it("only LinearStakingStorage role can write", async () => {
    await expect(
      lnLinearStakingStorage
        .connect(alice)
        .PushStakingData(
          charlie.address,
          100,
          new Date(2020, 0, 1).getTime() / 1000
        )
    ).to.revertedWith("Only Linear Staking Storage Role");

    lnLinearStakingStorage
      .connect(bob)
      .PushStakingData(
        charlie.address,
        100,
        new Date(2020, 0, 1).getTime() / 1000
      );
  });
});
