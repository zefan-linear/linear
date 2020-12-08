import { expect, use } from "chai";
import { Contract } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";

import LnAccessControl from "../build/development/LnAccessControl.json";

use(solidity);

/**
 * The current implementation of `LnAccessControl` is confusing and unnecessarily complicated:
 *   https://github.com/Linear-finance/linear/issues/2
 */

describe("LnAccessControl", () => {
  // Chain spawned outside of `beforeEach` as we're not testing time-dependent cases.
  const provider = new MockProvider({
    ganacheOptions: {
      time: new Date(2020, 0, 1),
    },
  });
  const [developer, alice, bob, charlie, david] = provider.getWallets();

  let lnAccessControl: Contract;

  beforeEach(async () => {
    lnAccessControl = await deployContract(developer, LnAccessControl, [
      alice.address,
    ]);
  });

  it("only admin can set admin", async () => {
    // Non-admin cannot set admin
    await expect(
      lnAccessControl.connect(bob).SetAdmin(charlie.address)
    ).to.revertedWith("Only admin");

    // Admin can set admin
    await lnAccessControl.connect(alice).SetAdmin(charlie.address);
  });

  it("multiple admins can co-exist", async () => {
    // Both Alice and Bob are admin
    await lnAccessControl.connect(alice).SetAdmin(bob.address);

    // Alice can still set admin
    await lnAccessControl.connect(alice).SetAdmin(charlie.address);

    // Bob can also set admin
    await lnAccessControl.connect(bob).SetAdmin(david.address);
  });

  it("only admin can set roles", async () => {
    await expect(
      lnAccessControl.connect(bob).SetIssueAssetRole([charlie.address], [true])
    ).to.revertedWith("AccessControl: sender must be an admin to grant");

    await expect(
      lnAccessControl.connect(bob).SetIssueAssetRole([charlie.address], [false])
    ).to.revertedWith("AccessControl: sender must be an admin to revoke");

    await expect(
      lnAccessControl.connect(bob).SetBurnAssetRole([charlie.address], [true])
    ).to.revertedWith("AccessControl: sender must be an admin to grant");

    await expect(
      lnAccessControl.connect(bob).SetBurnAssetRole([charlie.address], [false])
    ).to.revertedWith("AccessControl: sender must be an admin to revoke");

    await expect(
      lnAccessControl.connect(bob).SetDebtSystemRole([charlie.address], [true])
    ).to.revertedWith("AccessControl: sender must be an admin to grant");

    await expect(
      lnAccessControl.connect(bob).SetDebtSystemRole([charlie.address], [false])
    ).to.revertedWith("AccessControl: sender must be an admin to revoke");

    await lnAccessControl
      .connect(alice)
      .SetIssueAssetRole([bob.address], [true]);

    await lnAccessControl
      .connect(alice)
      .SetIssueAssetRole([bob.address], [false]);

    await lnAccessControl
      .connect(alice)
      .SetBurnAssetRole([bob.address], [true]);

    await lnAccessControl
      .connect(alice)
      .SetBurnAssetRole([bob.address], [false]);

    await lnAccessControl
      .connect(alice)
      .SetDebtSystemRole([bob.address], [true]);

    await lnAccessControl
      .connect(alice)
      .SetDebtSystemRole([bob.address], [false]);
  });

  // This test case was ported from the legacy case "access roles"
  it('legacy test case - "access roles"', async () => {
    const debtsystemKey = await lnAccessControl.DEBT_SYSTEM();
    const issueassetKey = await lnAccessControl.ISSUE_ASSET_ROLE();

    expect(await lnAccessControl.IsAdmin(alice.address)).to.equal(true);
    expect(await lnAccessControl.IsAdmin(bob.address)).to.equal(false);

    await expect(
      lnAccessControl.connect(charlie).SetAdmin(bob.address)
    ).to.revertedWith("Only admin");

    let addrs: string[] = [bob.address, charlie.address];
    let setTo: boolean[] = [true, true];

    await expect(
      lnAccessControl.connect(charlie).SetDebtSystemRole(addrs, setTo)
    ).to.revertedWith("AccessControl: sender must be an admin to grant");

    // Default
    expect(await lnAccessControl.hasRole(debtsystemKey, bob.address)).to.equal(
      false
    );
    expect(
      await lnAccessControl.hasRole(debtsystemKey, charlie.address)
    ).to.equal(false);
    expect(
      await lnAccessControl.hasRole(issueassetKey, charlie.address)
    ).to.equal(false);

    // Set to
    await lnAccessControl.connect(alice).SetDebtSystemRole(addrs, setTo);
    expect(await lnAccessControl.hasRole(debtsystemKey, bob.address)).to.equal(
      true
    );
    expect(
      await lnAccessControl.hasRole(debtsystemKey, charlie.address)
    ).to.equal(true);
    expect(
      await lnAccessControl.hasRole(issueassetKey, charlie.address)
    ).to.equal(false);

    // Reset
    setTo = [false, false];
    await lnAccessControl.connect(alice).SetDebtSystemRole(addrs, setTo);
    expect(await lnAccessControl.hasRole(debtsystemKey, bob.address)).to.equal(
      false
    );
    expect(
      await lnAccessControl.hasRole(debtsystemKey, charlie.address)
    ).to.equal(false);
    expect(
      await lnAccessControl.hasRole(issueassetKey, charlie.address)
    ).to.equal(false);

    expect(
      await lnAccessControl.hasRole(debtsystemKey, alice.address)
    ).to.equal(false);
  });
});
