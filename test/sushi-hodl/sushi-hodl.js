// Utilities
const Utils = require("../utilities/Utils.js");
const {
  impersonates,
  setupCoreProtocol,
  depositVault,
} = require("../utilities/hh-utils.js");

const { send, expectRevert, time } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);
const SushiHODLWallet = artifacts.require("SushiHODLWallet");

describe("Sushi HODL Wallet", function () {
  let accounts;

  // contracts
  let sushiAddress = "0x6B3595068778DD592e39A122f4f5a5cF09C90fE2";
  let sushi;
  let sushiBarAddress = "0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272";
  let sushiBar;
  let sushiHodlWallet;
  let atoken;
  let lendingPoolProvider = "0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5";
  let protocolDataProvider = "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d";

  // block 11914174
  let sushiWhale = "0x03492357c54f166615fa614d5ef88155c3717613";

  // parties in the test
  let owner;
  let recipient;
  let sushiDistribution;

  before(async function () {
    accounts = await web3.eth.getAccounts();
    owner = accounts[0];
    sushiDistribution = accounts[2];
    recipient = accounts[3];
    impersonates([sushiWhale]);
    // Give whale some ether to make sure the following actions are good
    let etherGiver = accounts[9];
    await send.ether(etherGiver, sushiWhale, new BigNumber("1e18"));
  });

  beforeEach(async function () {
    // Reset the tokens and the pool every time.
    sushiHodlWallet = await SushiHODLWallet.new(
      sushiDistribution,
      sushiAddress,
      sushiBarAddress,
      recipient,
      lendingPoolProvider,
      protocolDataProvider,
      { from: owner }
    );

    sushiBar = await IERC20.at(sushiBarAddress);
    sushi = await IERC20.at(sushiAddress);
    atoken = await IERC20.at(await sushiHodlWallet.aToken());
    await sushi.transfer(sushiWhale, await sushi.balanceOf(owner), {
      from: owner,
    });
    await sushi.transfer(sushiWhale, await sushi.balanceOf(recipient), {
      from: recipient,
    });
  });

  describe("Proper accessibility", async function () {
    it("Random roles cannot call any method", async function () {
      await expectRevert(
        sushiHodlWallet.withdraw(0, { from: sushiDistribution }),
        "caller is not the owner"
      );
      await expectRevert(
        sushiHodlWallet.toAave(0, { from: sushiDistribution }),
        "caller is not the owner"
      );
      await expectRevert(
        sushiHodlWallet.fromAave(0, { from: sushiDistribution }),
        "caller is not the owner"
      );
      await expectRevert(
        sushiHodlWallet.toSushiBar(0, { from: sushiDistribution }),
        "caller is not the owner"
      );
      await expectRevert(
        sushiHodlWallet.fromSushiBar(0, { from: sushiDistribution }),
        "caller is not the owner"
      );
      await expectRevert(
        sushiHodlWallet.wrap(0, 0, { from: sushiDistribution }),
        "caller is not the owner"
      );
      await expectRevert(
        sushiHodlWallet.unwrap(0, 0, { from: sushiDistribution }),
        "caller is not the owner"
      );
      await expectRevert(
        sushiHodlWallet.setRecipient(sushiDistribution, { from: sushiDistribution }),
        "caller is not the owner"
      );
      await expectRevert(
        sushiHodlWallet.salvage(owner, owner, 0, { from: sushiDistribution }),
        "caller is not the owner"
      );
      await expectRevert(
        sushiHodlWallet.salvageEth(owner, 0, { from: sushiDistribution }),
        "caller is not the owner"
      );
      await expectRevert(
        sushiHodlWallet.start(0, { from: owner }),
        "Only sushi distributor"
      );
    });
  });

  describe("Salvaging tokens", async function () {
    it("Some tokens cannot be salvaged", async function () {
      let amount = new BigNumber("1e18").multipliedBy("20");
      await sushi.transfer(sushiHodlWallet.address, amount, { from: sushiWhale });
      await sushiHodlWallet.start(0, { from: sushiDistribution });
      await expectRevert(
        sushiHodlWallet.salvage(owner, sushiAddress, amount),
        "the token cannot be salvaged"
      );
      Utils.assertBNEq(await sushi.balanceOf(owner), 0);
      Utils.assertBNEq(await sushi.balanceOf(sushiHodlWallet.address), amount);
      assert.isTrue(await sushiHodlWallet.unsalvageable(sushi.address));
      assert.isTrue(await sushiHodlWallet.unsalvageable(sushiBarAddress));
      assert.isTrue(await sushiHodlWallet.unsalvageable(await sushiHodlWallet.aToken()));
    });
  });

  describe("Initialization and Withdrawing", async function () {
    it("Initialization", async function () {
      let amount = new BigNumber("1e18").multipliedBy("2000");
      await sushi.transfer(sushiDistribution, amount, { from: sushiWhale });
      await sushi.approve(sushiHodlWallet.address, amount, { from: sushiDistribution });
      await sushiHodlWallet.start(amount, { from: sushiDistribution });
      let totalDeposited = await sushiHodlWallet.totalDeposited();
      Utils.assertBNEq(totalDeposited, amount);
    });

    it("Withdraw", async function () {
      let amount = new BigNumber("1e18").multipliedBy("2000");
      await sushi.transfer(sushiDistribution, amount, { from: sushiWhale });
      await sushi.approve(sushiHodlWallet.address, amount, { from: sushiDistribution });
      await sushiHodlWallet.start(amount, { from: sushiDistribution });
      Utils.assertBNEq(await sushiHodlWallet.totalDeposited(), amount);
      await sushiHodlWallet.withdraw(amount.dividedBy(2), { from: owner });
      Utils.assertBNEq(await sushiHodlWallet.totalDeposited(), amount);
      Utils.assertBNEq(
        await sushi.balanceOf(recipient),
        amount.dividedBy(2)
      );
      Utils.assertBNEq(
        await sushi.balanceOf(sushiHodlWallet.address),
        amount.dividedBy(2)
      );
    });
  });

  describe("Interactions", async function () {
    it("Pushing to and pulling it out of sushi bar", async function () {
      let amount = new BigNumber("1e18").multipliedBy("2000");
      await sushiHodlWallet.start(0, { from: sushiDistribution });

      await sushi.transfer(sushiHodlWallet.address, amount, { from: sushiWhale });
      await sushiHodlWallet.toSushiBar(amount.dividedBy(2));
      Utils.assertBNEq(
        amount.dividedBy(2),
        await sushi.balanceOf(sushiHodlWallet.address)
      );
      // we have a bit less than half, there is some exchange rate from sushi to xsushi
      Utils.assertBNGt(
        amount.dividedBy(2),
        await sushiBar.balanceOf(sushiHodlWallet.address)
      );
      await sushiHodlWallet.fromSushiBar(await sushiBar.balanceOf(sushiHodlWallet.address));
      Utils.assertBNEq(
        amount,
        // off-by-one error happening when pushing into sushi and pulling back
        new BigNumber(await sushi.balanceOf(sushiHodlWallet.address)).plus(1)
      );
      Utils.assertBNEq(0, await sushiBar.balanceOf(sushiHodlWallet.address));
    });

    it("Pushing to and pulling from aave", async function () {
      let amount = new BigNumber("1e18").multipliedBy("2000");
      await sushiHodlWallet.start(0, { from: sushiDistribution });

      await sushi.transfer(sushiHodlWallet.address, amount, { from: sushiWhale });
      await sushiHodlWallet.toSushiBar(amount.dividedBy(2));
      let xsushiBalance = await sushiBar.balanceOf(sushiHodlWallet.address);
      let halfOfXSushi = new BigNumber(xsushiBalance).dividedBy(2);
      await sushiHodlWallet.toAave(halfOfXSushi);
      // we have a bit less than half, there is some exchange rate from sushi to xsushi
      Utils.assertBNEq(
        amount.dividedBy(2),
        await sushi.balanceOf(sushiHodlWallet.address)
      );
      Utils.assertBNGt(amount.dividedBy(4), halfOfXSushi);
      // we should have the same number of xsushi and atokens
      // off-by one error is possible when the number is odd
      Utils.assertBNEq(
        new BigNumber(await sushiBar.balanceOf(sushiHodlWallet.address)).plus(1),
        new BigNumber(await atoken.balanceOf(sushiHodlWallet.address))
      );
      // pull everything out
      await sushiHodlWallet.fromAave(await atoken.balanceOf(sushiHodlWallet.address));
      await sushiHodlWallet.fromSushiBar(await sushiBar.balanceOf(sushiHodlWallet.address));
      Utils.assertBNEq(0, await sushiBar.balanceOf(sushiHodlWallet.address));
      // We get all the xsushi back, plus some additional a tokens
      Utils.assertBNGt(await atoken.balanceOf(sushiHodlWallet.address), 0);
      Utils.assertBNEq(
        amount,
        // off-by-one error happening when pushing into sushi and pulling back
        new BigNumber(await sushi.balanceOf(sushiHodlWallet.address)).plus(1)
      );
      // We can also get the remaining tokens out of aave
      await sushiHodlWallet.fromAave(await atoken.balanceOf(sushiHodlWallet.address));
      await sushiHodlWallet.fromSushiBar(await sushiBar.balanceOf(sushiHodlWallet.address));
      Utils.assertBNGt(await sushi.balanceOf(sushiHodlWallet.address), amount);
    });

    it("Combination methods", async function () {
      let amount = new BigNumber("1e18").multipliedBy("2000");
      await sushiHodlWallet.start(0, { from: sushiDistribution });
      await sushi.transfer(sushiHodlWallet.address, amount, { from: sushiWhale });
      await sushiHodlWallet.wrap(amount.dividedBy(2), amount.dividedBy(4));
      Utils.assertBNEq(
        amount.dividedBy(2),
        await sushi.balanceOf(sushiHodlWallet.address)
      );
      await sushiHodlWallet.unwrap(
        new BigNumber(await sushiBar.balanceOf(sushiHodlWallet.address)).plus(
          await atoken.balanceOf(sushiHodlWallet.address)
        ),
        await atoken.balanceOf(sushiHodlWallet.address)
      );
      Utils.assertBNEq(
        amount,
        // off-by-one error happening when pushing into sushi and pulling back
        new BigNumber(await sushi.balanceOf(sushiHodlWallet.address)).plus(1)
      );
    });
  });

  describe("Administration", async function () {
    it("Setting new recipient", async function () {
      await expectRevert(
        sushiHodlWallet.setRecipient("0x0000000000000000000000000000000000000000", {
          from: owner,
        }),
        "invalid recipient"
      );
      await sushiHodlWallet.setRecipient(owner, { from: owner });
      assert.equal(owner, await sushiHodlWallet.recipient());
    });
  });
});
