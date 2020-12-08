import { expect, use } from "chai";
import { Contract } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";

import { expandTo18Decimals, zeroAddress } from "./utilities";

import LinearFinance from "../build/development/LinearFinance.json";
import LnProxyERC20 from "../build/development/LnProxyERC20.json";
import LnTokenStorage from "../build/development/LnTokenStorage.json";

use(solidity);

/**
 * Since admin privileges for LINA token related contracts have been given up
 * on mainnet, and is thus immutable, only simple test cases are included here
 * for illustrating how contracts interact with each other.
 */

describe("LinearFinance", () => {
  // Chain spawned outside of `beforeEach` as we're not testing time-dependent cases.
  const provider = new MockProvider({
    ganacheOptions: {
      time: new Date(2020, 0, 1),
    },
  });
  const [developer, alice, bob, charlie, david] = provider.getWallets();

  let linearFinance: Contract;
  let lnProxyERC20: Contract;
  let lnTokenStorage: Contract;

  beforeEach(async () => {
    lnProxyERC20 = await deployContract(developer, LnProxyERC20, [
      alice.address, // _admin
    ]);

    // Not setting operator yet as the token contract hasn't been implemented
    lnTokenStorage = await deployContract(developer, LnTokenStorage, [
      alice.address, // _admin
      zeroAddress, // _operator
    ]);

    linearFinance = await deployContract(developer, LinearFinance, [
      lnProxyERC20.address, // _proxy
      lnTokenStorage.address, // _tokenStorage
      alice.address, // _admin
      0, // _totalSupply
    ]);

    await lnProxyERC20.connect(alice).setTarget(linearFinance.address);
    await lnTokenStorage.connect(alice).setOperator(linearFinance.address);
  });

  it("only admin can mint", async () => {
    await expect(
      linearFinance.connect(bob).mint(bob.address, 100)
    ).to.revertedWith("Only the contract admin can perform this action");

    await linearFinance.connect(alice).mint(bob.address, 100);
  });

  it("cannot mint over max supply", async () => {
    expect(await linearFinance.totalSupply()).to.equal(0);
    expect(await linearFinance.balanceOf(bob.address)).to.equal(0);

    await linearFinance
      .connect(alice)
      .mint(bob.address, expandTo18Decimals(1_000_000_000));

    expect(await linearFinance.totalSupply()).to.equal(
      expandTo18Decimals(1_000_000_000)
    );
    expect(await linearFinance.balanceOf(bob.address)).to.equal(
      expandTo18Decimals(1_000_000_000)
    );

    await expect(
      linearFinance
        .connect(alice)
        .mint(bob.address, expandTo18Decimals(9_000_000_001))
    ).to.revertedWith("Can not mint over max supply");
  });

  it("transfer event emits on proxy", async () => {
    await expect(linearFinance.connect(alice).mint(bob.address, 100))
      .to.emit(lnProxyERC20, "Transfer")
      .withArgs(zeroAddress, bob.address, 100);

    await expect(linearFinance.connect(bob).transfer(charlie.address, 30))
      .to.emit(lnProxyERC20, "Transfer")
      .withArgs(bob.address, charlie.address, 30);

    await expect(lnProxyERC20.connect(bob).transfer(charlie.address, 70))
      .to.emit(lnProxyERC20, "Transfer")
      .withArgs(bob.address, charlie.address, 70);
  });
});
