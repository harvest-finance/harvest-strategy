// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send, time } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

//const Strategy = artifacts.require("");
const Strategy = artifacts.require("MithCash2FarmStrategyMainnet_MIC_USDT");
const RewardDistributionSwitcher = artifacts.require("RewardDistributionSwitcher");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("MITH MIC_USDT", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup, block: 11688935
  let underlyingWhale = "0x89d502a98615c69d8080556937dccb35585de675";

  // parties in the protocol
  let governance;
  let farmer1;

  // numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let controller;
  let vault;
  let strategy;
  let farm;

  async function setupExternalContracts() {
    underlying = await IERC20.at("0xC9cB53B48A2f3A9e75982685644c1870F1405CCb");
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
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale]);

    rewardDistributionSwitcher = await RewardDistributionSwitcher.new(
      addresses.Storage
    );
    await setupExternalContracts();
    [controller, vault, strategy, rewardPool] = await setupCoreProtocol({
      "existingVaultAddress": "0x6F14165c6D529eA3Bfe1814d0998449e9c8D157D",
      "existingRewardPoolAddress": "0x98Ba5E432933E2D536e24A2C021deBb8404588C1",
      "strategyArtifact": Strategy,
      "strategyArgs": [addresses.Storage, "vaultAddr", "poolAddr", rewardDistributionSwitcher.address],
      "underlying": underlying,
      "governance": governance,
      "announceStrategy": true
    });

    await time.increase(86400 * 30);
    await rewardPool.transferOwnership(rewardDistributionSwitcher.address, {from: governance});
    await rewardDistributionSwitcher.setSwitcher(strategy.address, true, {from:governance});

    farm = await IERC20.at(addresses.FARM);
    // whale send underlying to farmers
    await setupBalance();
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
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);
        let blocksPerHour = 2400;
        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log("old shareprice: ", oldSharePrice.toFixed());
        console.log("new shareprice: ", newSharePrice.toFixed());
        console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());

        await Utils.advanceNBlock(blocksPerHour);
      }
      await rewardPool.exit({from: farmer1});
      await vault.withdraw(new BigNumber(await vault.balanceOf(farmer1)).toFixed(), { from: farmer1 });
      let farmerNewFarm = new BigNumber(await farm.balanceOf(farmer1));
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));

      console.log("farmerNewFarm:    ", farmerNewFarm.toFixed());
      console.log("farmerOldBalance: ", farmerOldBalance.toFixed());
      console.log("farmerNewBalance: ", farmerNewBalance.toFixed());
      Utils.assertBNGt(farmerNewFarm, 0);
      console.log("earned!");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
