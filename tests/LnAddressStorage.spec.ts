import { expect, use } from "chai";
import { Contract, ethers } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";

import { zeroAddress } from "./utilities";

import LnAddressStorage from "../build/development/LnAddressStorage.json";
import TestAddressCache from "../build/development/TestAddressCache.json";

use(solidity);

describe("LnAddressStorage", () => {
  // Chain spawned outside of `beforeEach` as we're not testing time-dependent cases.
  const provider = new MockProvider({
    ganacheOptions: {
      time: new Date(2020, 0, 1),
    },
  });
  const [developer, alice, bob, charlie, david] = provider.getWallets();

  let lnAddressStorage: Contract;

  beforeEach(async () => {
    lnAddressStorage = await deployContract(developer, LnAddressStorage, [
      alice.address,
    ]);
  });

  it("only admin can update", async () => {
    await expect(
      lnAddressStorage
        .connect(bob)
        .update(ethers.utils.formatBytes32String("test"), alice.address)
    ).to.revertedWith("Only the contract admin can perform this action");

    await expect(
      lnAddressStorage
        .connect(bob)
        .updateAll([ethers.utils.formatBytes32String("test")], [alice.address])
    ).to.revertedWith("Only the contract admin can perform this action");

    await lnAddressStorage
      .connect(alice)
      .update(ethers.utils.formatBytes32String("test"), alice.address);

    await lnAddressStorage
      .connect(alice)
      .updateAll([ethers.utils.formatBytes32String("test")], [alice.address]);
  });

  it("address changed after update", async () => {
    expect(
      await lnAddressStorage.getAddress(
        ethers.utils.formatBytes32String("test")
      )
    ).to.equal(zeroAddress);

    await lnAddressStorage
      .connect(alice)
      .update(ethers.utils.formatBytes32String("test"), bob.address);

    expect(
      await lnAddressStorage.getAddress(
        ethers.utils.formatBytes32String("test")
      )
    ).to.equal(bob.address);
  });

  it("required read fails with zero address", async () => {
    await lnAddressStorage
      .connect(alice)
      .update(ethers.utils.formatBytes32String("test"), bob.address);

    expect(
      await lnAddressStorage.getAddressWithRequire(
        ethers.utils.formatBytes32String("test"),
        "empty address"
      )
    ).to.equal(bob.address);

    await expect(
      lnAddressStorage.getAddressWithRequire(
        ethers.utils.formatBytes32String("empty"),
        "empty address"
      )
    ).to.revertedWith("empty address");
  });

  // This test case was ported from the legacy case "test LnAddressStorage"
  it('legacy test case - "test LnAddressStorage"', async () => {
    await lnAddressStorage
      .connect(alice)
      .update(ethers.utils.formatBytes32String("a"), lnAddressStorage.address);
    await lnAddressStorage
      .connect(alice)
      .update(ethers.utils.formatBytes32String("b"), lnAddressStorage.address);

    const testAddressCache: Contract = await deployContract(
      developer,
      TestAddressCache,
      [alice.address]
    );

    await testAddressCache
      .connect(alice)
      .updateAddressCache(lnAddressStorage.address);

    expect(await testAddressCache.addr1(), lnAddressStorage.address);
    expect(await testAddressCache.addr2(), lnAddressStorage.address);

    await lnAddressStorage
      .connect(alice)
      .updateAll(
        [
          ethers.utils.formatBytes32String("a"),
          ethers.utils.formatBytes32String("b"),
        ],
        [alice.address, bob.address]
      );

    await testAddressCache
      .connect(alice)
      .updateAddressCache(lnAddressStorage.address);
    expect(await testAddressCache.addr1(), alice.address);
    expect(await testAddressCache.addr2(), bob.address);
  });
});
