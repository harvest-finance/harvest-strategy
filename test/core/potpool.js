// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault, setupFactory } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send, expectRevert } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const MockERC20 = artifacts.require("MockERC20");
const PotPoolFactory = artifacts.require("PotPoolFactory");
const MegaFactory = artifacts.require("MegaFactory");
const RegularVaultFactory = artifacts.require("RegularVaultFactory");
const PotPool = artifacts.require("PotPool");
const IPotPool = artifacts.require("IPotPoolCustomOverride");
const IVault = artifacts.require("IVault");

// block number: 13639563

describe("Potpool test", function() {
  let accounts;

  // contracts
  let lpToken;
  let rewardToken1;
  let rewardToken2;
  let rewardToken3;

  let potPool;
  let megaFactory;

  // parties in the protocol
  let governance;
  let farmer1;
  let farmer2;
  let rewardDistributor1;
  let rewardDistributor2;

  let farmer1FullAmount = "10000000";
  let farmer1HalfAmount = "5000000";
  let farmer1QuaterAmount = "2500000";

  before(async function() {
    accounts = await web3.eth.getAccounts();
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    farmer1 = accounts[1];
    farmer2 = accounts[2];
    rewardDistributor1 = accounts[3];
    rewardDistributor2 = accounts[4];

    await impersonates([governance]);
  });

  beforeEach(async function() {
    // Reset the tokens and the pool every time.

    const lpTokenUnderlying = await MockERC20.new("LP");
    rewardToken1 = await MockERC20.new("reward1");
    rewardToken2 = await MockERC20.new("reward2");
    rewardToken3 = await MockERC20.new("reward3");

    [megaFactory, potPoolFactory] = await setupFactory();
    await potPoolFactory.setPoolDefaultDuration("100000");
    await megaFactory.createRegularVault("mock", lpTokenUnderlying.address);

    potPool = await PotPool.at((await megaFactory.completedDeployments("mock")).NewPool);
    lpToken = await IERC20.at((await megaFactory.completedDeployments("mock")).NewVault);

    await potPool.setRewardDistribution([rewardDistributor1], true);
    await potPool.addRewardToken(rewardToken1.address);
    await potPool.removeRewardToken(addresses.IFARM); // removing iFARM that was set by default

    await lpTokenUnderlying.mint(farmer1, farmer1FullAmount);
    await lpTokenUnderlying.mint(farmer2, farmer1FullAmount);

    await lpTokenUnderlying.approve(lpToken.address, farmer1FullAmount, {from: farmer1});
    await lpTokenUnderlying.approve(lpToken.address, farmer1FullAmount, {from: farmer2});

    const lpTokenVault = await IVault.at(lpToken.address);

    await lpTokenVault.deposit(farmer1FullAmount, {from: farmer1});
    await lpTokenVault.deposit(farmer1FullAmount, {from: farmer2});
  });

  async function mintRewardAndNotify(rewardToken, amount) {
    await rewardToken.mint(potPool.address, amount);
    await potPool.notifyTargetRewardAmount(rewardToken.address, amount, {from: rewardDistributor1});
  }

  describe("Happy path", function() {
    it("Farmer1 should get reward token when staking", async function() {
      await lpToken.approve(potPool.address, farmer1FullAmount, {from: farmer1});
      await potPool.stake(farmer1FullAmount, {from:farmer1});

      // governance send rewardToken1 to pool and notify
      await mintRewardAndNotify(rewardToken1, farmer1FullAmount);
      await Utils.waitTime(100000);

      await potPool.exit({from:farmer1});
      Utils.assertBNEq(farmer1FullAmount, await rewardToken1.balanceOf(farmer1));
    });

    it("Farmer1 and Farmer2 should get half of the reward token when staking", async function() {
      await lpToken.approve(potPool.address, farmer1FullAmount, {from: farmer1});
      await potPool.stake(farmer1FullAmount, {from:farmer1});

      await lpToken.approve(potPool.address, farmer1FullAmount, {from: farmer2});
      await potPool.stake(farmer1FullAmount, {from:farmer2});

      // governance send rewardToken1 to pool and notify
      await mintRewardAndNotify(rewardToken1, farmer1FullAmount);
      await Utils.waitTime(100000);

      await potPool.exit({from:farmer1});
      await potPool.exit({from:farmer2});
      Utils.assertBNEq(farmer1HalfAmount, await rewardToken1.balanceOf(farmer1));
      Utils.assertBNEq(farmer1HalfAmount, await rewardToken1.balanceOf(farmer2));
    });

    it("Farmer1 and Farmer2 should get half of the reward tokens (2) when staking", async function() {
      await lpToken.approve(potPool.address, farmer1FullAmount, {from: farmer1});
      await potPool.stake(farmer1FullAmount, {from:farmer1});

      await lpToken.approve(potPool.address, farmer1FullAmount, {from: farmer2});
      await potPool.stake(farmer1FullAmount, {from:farmer2});

      // governance send rewardToken1 to pool and notify
      await mintRewardAndNotify(rewardToken1, farmer1FullAmount);
      await potPool.addRewardToken(rewardToken2.address, {from:governance});
      await mintRewardAndNotify(rewardToken2, farmer1HalfAmount);
      await Utils.waitTime(100000);

      await potPool.exit({from:farmer1});
      await potPool.exit({from:farmer2});
      Utils.assertBNEq(farmer1HalfAmount, await rewardToken1.balanceOf(farmer1));
      Utils.assertBNEq(farmer1QuaterAmount, await rewardToken2.balanceOf(farmer2));
    });
  });

  describe("Various edge cases", function() {
    it("Receipt cannot be used to get the reward. Can only withdraw with the receipt.", async function() {
      await lpToken.approve(potPool.address, farmer1FullAmount, {from: farmer1});
      await potPool.stake(farmer1FullAmount, {from:farmer1});
      await potPool.transfer(farmer2, farmer1FullAmount, {from:farmer1});

      // governance send rewardToken1 to pool and notify
      await mintRewardAndNotify(rewardToken1, farmer1FullAmount);
      await Utils.waitTime(100000);

      // If one's not a staker, then it cannot withdraw with a receipt
      await expectRevert.unspecified(potPool.exit({from:farmer2}));

      // trying to claim the reward while one is not a staker, should get nothing.
      await potPool.getAllRewards({from:farmer2});
      Utils.assertBNEq("0", await rewardToken1.balanceOf(farmer2));

      // Transfer the receipt back to the original staker
      // Original staker exits.
      await potPool.transfer(farmer1, farmer1FullAmount, {from:farmer2});
      await potPool.exit({from:farmer1});
      Utils.assertBNEq(farmer1FullAmount, await rewardToken1.balanceOf(farmer1));
    });

    it("Cannot remove token when it is still emitting rewards", async function(){
      // governance send rewardToken1 to pool and notify
      await mintRewardAndNotify(rewardToken1, farmer1FullAmount);
      await Utils.waitTime(20000);
      await potPool.addRewardToken(rewardToken2.address, {from:governance});
      await mintRewardAndNotify(rewardToken2, farmer1FullAmount);
      await Utils.waitTime(10000);

      // Should revert when rewardToken is still emitting rewards
      await expectRevert(potPool.removeRewardToken(rewardToken2.address, {from:governance}), "Can only remove when the reward period has passed");
    });

    it("Add token, then remove token, then add the token back. ", async function(){
      // People should get all the reward back in this scenario

      await lpToken.approve(potPool.address, farmer1FullAmount, {from: farmer1});
      // farmer1 staked
      await potPool.stake(farmer1FullAmount, {from:farmer1});

      // governance send rewardToken1 to pool and notify
      await mintRewardAndNotify(rewardToken1, farmer1FullAmount);
      await Utils.waitTime(20000);
      await potPool.addRewardToken(rewardToken2.address, {from:governance});
      await mintRewardAndNotify(rewardToken2, farmer1FullAmount);
      await Utils.waitTime(10000);

      // farmer1 transfers staking receipt to farmer2
      await potPool.transfer(farmer2, farmer1FullAmount, {from:farmer1});

      // making sure the time passed for emission
      await Utils.waitTime(110000);

      // remove the rewardToken then add it back.
      await potPool.removeRewardToken(rewardToken2.address, {from:governance});
      await potPool.addRewardToken(rewardToken2.address, {from:governance});

      // farmer1 exit should still get the rewardToken that was added back
      await potPool.transfer(farmer1, farmer1FullAmount, {from:farmer2});
      await potPool.exit({from:farmer1});
      await potPool.getAllRewards({from:farmer2});

      Utils.assertBNEq(farmer1FullAmount, await rewardToken1.balanceOf(farmer1));
      Utils.assertBNEq("0", await rewardToken1.balanceOf(farmer2));
      Utils.assertBNEq(farmer1FullAmount, await rewardToken2.balanceOf(farmer1));
      Utils.assertBNEq("0", await rewardToken2.balanceOf(farmer2));
    });

    it("Add token as reward distribution", async function() {
      await expectRevert(potPool.addRewardToken(rewardToken2.address, {from:farmer1}), "Not governance nor reward distribution");
      await potPool.addRewardToken(rewardToken2.address, {from:rewardDistributor1});
      await mintRewardAndNotify(rewardToken2, farmer1FullAmount);
    });

    it("Add token, then remove token. People can still claim the removed reward token.", async function(){

      // People should get what is in the reward token list
      await lpToken.approve(potPool.address, farmer1FullAmount, {from: farmer1});
      await potPool.stake(farmer1FullAmount, {from:farmer1});

      // governance send rewardToken1 to pool and notify
      await mintRewardAndNotify(rewardToken1, farmer1FullAmount);
      await Utils.waitTime(20000);

      // Adding the rewardToken2 and notify
      await potPool.addRewardToken(rewardToken2.address, {from:governance});
      await mintRewardAndNotify(rewardToken2, farmer1FullAmount);
      await Utils.waitTime(10000);

      // transfering the staking receipt to farmer2
      await potPool.transfer(farmer2, farmer1FullAmount, {from:farmer1});

      // Time has fully passed for both emission
      await Utils.waitTime(1000000);

      // removing rewardToken2 from the list
      await potPool.removeRewardToken(rewardToken2.address, {from:governance});
      await Utils.waitTime(1000);

      await potPool.getAllRewards({from:farmer1});
      await potPool.getAllRewards({from:farmer2});
      Utils.assertBNEq(farmer1FullAmount, new BigNumber(await rewardToken1.balanceOf(farmer1)).plus(await rewardToken1.balanceOf(farmer2))) ;
      Utils.assertBNEq("0", new BigNumber(await rewardToken2.balanceOf(farmer1)).plus(await rewardToken2.balanceOf(farmer2)));

      // web3 doesn't handle repeated function name nicely, thus we need to manually convert
      let ipotPool = await IPotPool.at(potPool.address);

      // We did not add the token back to the list, but people should still be able to get their reward by exclusively asking for them
      await ipotPool.getReward(rewardToken2.address, {from:farmer1});
      await ipotPool.getReward(rewardToken2.address, {from:farmer2});
      Utils.assertBNEq(farmer1FullAmount, new BigNumber(await rewardToken2.balanceOf(farmer1)).plus(await rewardToken2.balanceOf(farmer2))) ;
    });

    it("Staking receipt holder shouldn't be able to get reward if it is not the staker", async function(){
      // People should get what is in the reward token list
      await lpToken.approve(potPool.address, farmer1FullAmount, {from: farmer1});
      await potPool.stake(farmer1FullAmount, {from:farmer1});
      await potPool.transfer(farmer2, farmer1FullAmount, {from:farmer1});

      // governance send rewardToken1 to pool and notify
      await mintRewardAndNotify(rewardToken1, farmer1FullAmount);
      await Utils.waitTime(1000000);

      await potPool.getAllRewards({from:farmer1});
      await potPool.getAllRewards({from:farmer2});
      Utils.assertBNEq(farmer1FullAmount, new BigNumber(await rewardToken1.balanceOf(farmer1)).plus(await rewardToken1.balanceOf(farmer2))) ;
      Utils.assertBNEq("0", new BigNumber(await rewardToken2.balanceOf(farmer1)).plus(await rewardToken2.balanceOf(farmer2)));
    });

    it("Staking receipt holder should only remove ones own stake", async function(){
      // People should get what is in the reward token list
      await lpToken.approve(potPool.address, farmer1FullAmount, {from: farmer1});
      await potPool.stake(farmer1FullAmount, {from:farmer1});
      await lpToken.approve(potPool.address, farmer1FullAmount, {from: farmer2});
      await potPool.stake(farmer1FullAmount, {from:farmer2});
      await potPool.transfer(farmer2, farmer1FullAmount, {from:farmer1});

      // governance send rewardToken1 to pool and notify
      await mintRewardAndNotify(rewardToken1, farmer1FullAmount);
      await Utils.waitTime(1000000);

      // Trying to exit without receipt would fail
      await expectRevert.unspecified(potPool.exit({from:farmer1}));
      // exits with its own stake. The other receipts are kept
      await potPool.exit({from:farmer2});

      // Return the receipt to farmer1
      await potPool.transfer(farmer1, farmer1FullAmount, {from:farmer2});

      // farmer1 exits
      await potPool.exit({from:farmer1});

      Utils.assertBNEq(farmer1HalfAmount, await rewardToken1.balanceOf(farmer1));
      Utils.assertBNEq(farmer1HalfAmount, await rewardToken1.balanceOf(farmer2));
    });
  });
});
