import { expect, use } from "chai";
import { Contract } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";

import { zeroAddress } from "./utilities";

import LnAdmin from "../build/development/LnAdmin.json";

use(solidity);

describe("LnAdmin", () => {
  // Chain spawned outside of `beforeEach` as we're not testing time-dependent cases.
  const provider = new MockProvider({
    ganacheOptions: {
      time: new Date(2020, 0, 1),
    },
  });
  const [developer, alice, bob, charlie, david] = provider.getWallets();

  let lnAdmin: Contract;

  beforeEach(async () => {
    lnAdmin = await deployContract(developer, LnAdmin, [alice.address]);
  });

  it("only admin can set candidate", async () => {
    await expect(
      lnAdmin.connect(bob).setCandidate(charlie.address)
    ).to.revertedWith("Only the contract admin can perform this action");

    await lnAdmin.connect(alice).setCandidate(charlie.address);
  });

  it("only candicate can become admin", async () => {
    // Charlie promoted as candidate
    await expect(lnAdmin.connect(alice).setCandidate(charlie.address))
      .to.emit(lnAdmin, "candidateChanged")
      .withArgs(zeroAddress, charlie.address);

    // Others cannot become admin
    await expect(lnAdmin.connect(bob).becomeAdmin()).to.revertedWith(
      "Only candidate can become admin"
    );

    // Even admin cannot become admin
    await expect(lnAdmin.connect(alice).becomeAdmin()).to.revertedWith(
      "Only candidate can become admin"
    );

    // Candidate becomes admin
    await expect(lnAdmin.connect(charlie).becomeAdmin())
      .to.emit(lnAdmin, "AdminChanged")
      .withArgs(alice.address, charlie.address);
  });

  it("old admin cannot set candidate", async () => {
    // Charlie replaces Alice as admin
    await lnAdmin.connect(alice).setCandidate(charlie.address);
    await lnAdmin.connect(charlie).becomeAdmin();

    // Alice no longer has admin privileges
    await expect(
      lnAdmin.connect(alice).setCandidate(bob.address)
    ).to.revertedWith("Only the contract admin can perform this action");
  });
});
