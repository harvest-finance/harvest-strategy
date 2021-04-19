// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

//const Strategy = artifacts.require("");
const Strategy = artifacts.require("IndexStrategyMainnet_MVI_ETH");
const RewardPool = artifacts.require("NoMintRewardPool");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Index MVI/ETH", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  // blockNumber 12199065
  let underlyingWhale = "0x82703281e7ff09cd2492ddb6b8c5fa645efda819";
  let rewardDistribution = "0x9467cfADC9DE245010dF95Ec6a585A506A8ad5FC";
  let rewardPoolAddr = "0x5bC4249641B4bf4E37EF513F3Fa5C63ECAB34881";
  let index = "0x0954906da0Bf32d5479e25f46056d22f08464cab";

  // parties in the protocol
  let governance;
  let farmer1;

  // numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let controller;
  let vault;
  let strategy;

  async function setupExternalContracts() {
    underlying = await IERC20.at("0x4d3C5dB2C68f6859e0Cd05D080979f597DD64bff");
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance(){
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await send.ether(etherGiver, underlyingWhale, "1" + "000000000000000000");
    await send.ether(etherGiver, rewardDistribution, "1" + "000000000000000000");


    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, { from: underlyingWhale });
  }

  before(async function() {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale, rewardDistribution]);

    await setupExternalContracts();
    [controller, vault, strategy] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": Strategy,
      "underlying": underlying,
      "governance": governance,
    });

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);

      // Distribute reward
      rewardPool = await RewardPool.at(rewardPoolAddr);
      rewardToken = await IERC20.at(index);
      await rewardToken.transfer(rewardPoolAddr, "3250" + "000000000000000000", {from: rewardDistribution});
      await rewardPool.notifyRewardAmount("3250" + "000000000000000000", {from: rewardDistribution});


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
      await vault.withdraw(new BigNumber(await vault.balanceOf(farmer1)).toFixed(), { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      Utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      console.log("earned!");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
