// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

//const Strategy = artifacts.require("");
const Strategy = artifacts.require("NFT20Strategy_MUSE");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("NFT2 MUSE-ETH", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  // block: 12369538
  let underlyingWhale = "0xc9f202deb231891e6cde1f6d4af18566bcaef6f0";

  // parties in the protocol
  let governance;
  let farmer1;

  // numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let controller;
  let vault;
  let strategy;
  let iFarm;

  async function setupExternalContracts() {
    underlying = await IERC20.at("0x20d2c17d1928ef4290bf17f922a10eaa2770bf43");
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance(){
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await send.ether(etherGiver, underlyingWhale, "1" + "000000000000000000");

    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, { from: underlyingWhale });
  }

  before(async function() {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    multiSig = "0xF49440C1F012d041802b25A73e5B0B9166a75c02";
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale, multiSig]);

    await setupExternalContracts();
    [controller, vault, strategy, rewardPool] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": Strategy,
      "strategyArgs": [addresses.Storage, "vaultAddr", "poolAddr"],
      "rewardPool" : true,
      "rewardPoolConfig": {
        type: 'PotPool',
        rewardTokens: [addresses.IFARM]
      },
      "strategyArtifactIsUpgradable": true,
      "underlying": underlying,
      "governance": governance,
    });

    // whale send underlying to farmers
    await setupBalance();
    iFarm = await IERC20.at(addresses.IFARM);
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);

      let farmerVaultShare = new BigNumber(await vault.balanceOf(farmer1)).toFixed();
      let vaultERC20 = await IERC20.at(vault.address);
      await vaultERC20.approve(rewardPool.address, farmerVaultShare, {from: farmer1});
      await rewardPool.stake(farmerVaultShare, {from: farmer1});

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let oldSharePrice;
      let newSharePrice;

      // Not selling, so doHardWork wouldn't sell rewards
      await strategy.setSell(false, {from: governance});

      await strategy.setRewardClaimable(true, {from: governance});

      oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
      await controller.doHardWork(vault.address, { from: governance });
      newSharePrice = new BigNumber(await vault.getPricePerFullShare());


      let reward = await IERC20.at("0xB6Ca7399B4F9CA56FC27cBfF44F4d2e4Eef1fc81");
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);
        let blocksPerHour = 2400;
        let rewardBalanceBefore = new BigNumber(await reward.balanceOf(multiSig));
        await strategy.claimReward({from: multiSig});
        let rewardBalanceAfter = new BigNumber(await reward.balanceOf(multiSig));

        console.log("rewardBalanceBefore: ", rewardBalanceBefore.toFixed());
        console.log("rewardBalanceAfter: ", rewardBalanceAfter.toFixed());
        console.log("diff: ", (rewardBalanceAfter.minus(rewardBalanceBefore)).toFixed());

        await Utils.advanceNBlock(blocksPerHour);
      }
      await rewardPool.exit({from: farmer1});
      let farmerNewIFarm = new BigNumber(await iFarm.balanceOf(farmer1));
      console.log("farmerNewIFarm:    ", farmerNewIFarm.toFixed());

      const vaultBalance = new BigNumber(await vault.balanceOf(farmer1));
      console.log("vaultBalance: ", vaultBalance.toFixed());

      await vault.withdraw(vaultBalance.toFixed(), { from: farmer1 });

      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      console.log("farmerOldBalance: ", farmerOldBalance.toFixed());
      console.log("farmerNewBalance: ", farmerNewBalance.toFixed());
      Utils.assertBNEq(farmerNewBalance, farmerOldBalance);
      console.log("got the same amount back");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
