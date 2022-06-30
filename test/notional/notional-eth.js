// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const { web3 } = require("@openzeppelin/test-helpers/src/setup.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const IFeeForwarder = artifacts.require("IFeeRewardForwarderV6");

//const Strategy = artifacts.require("");
const Strategy = artifacts.require("NotionalStrategy_ETH");

//This test was developed at blockNumber 12785750

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Notional: ETH", function () {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  let underlyingWhale = "0x39eea0258a5c3e3c5092b2f910371d124592a7fb";

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
    underlying = await IERC20.at("0xabc07BF91469C5450D6941dD0770E6E6761B90d6");
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance() {
    let etherGiver = accounts[9];

    // Give whale some ether to make sure the following actions are good
    await send.ether(etherGiver, underlyingWhale, "1" + "0000000000000000000");
    await send.ether(etherGiver, governance, "1" + "000000000000000000");

    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, { from: underlyingWhale });
  }

  before(async function () {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale]);

    await setupExternalContracts();

    // whale send underlying to farmers
    await setupBalance();

    [controller, vault, strategy] = await setupCoreProtocol({
      existingVaultAddress: null,
      strategyArtifact: Strategy,
      strategyArtifactIsUpgradable: true,
      underlying: underlying,
      governance: governance,
    });

    // Else sellfloor will not be reached
    await strategy.setSellFloor(0, { from: governance });
  });

  describe("Happy path", function () {
    it("Farmer should earn money", async function () {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));

      await depositVault(farmer1, underlying, vault, farmerBalance);

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let blocksPerHour = 2400;
      let oldSharePrice;
      let newSharePrice;
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);
        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log("old shareprice: ", oldSharePrice.toFixed());
        console.log("new shareprice: ", newSharePrice.toFixed());
        console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());

        apr = (newSharePrice.toFixed() / oldSharePrice.toFixed() - 1) * (24 / (blocksPerHour / 272)) * 365;
        apy = ((newSharePrice.toFixed() / oldSharePrice.toFixed() - 1) * (24 / (blocksPerHour / 272)) + 1) ** 365;

        console.log("instant APR:", apr * 100, "%");
        console.log("instant APY:", (apy - 1) * 100, "%");

        await Utils.advanceNBlock(blocksPerHour);
      }
      const vaultBalance = new BigNumber(await vault.balanceOf(farmer1));
      console.log("vaultBalance: ", vaultBalance.toFixed());

      await vault.withdraw(vaultBalance.toFixed(), { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      Utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      apr =
        (farmerNewBalance.toFixed() / farmerOldBalance.toFixed() - 1) * (24 / ((blocksPerHour * hours) / 272)) * 365;
      apy =
        ((farmerNewBalance.toFixed() / farmerOldBalance.toFixed() - 1) * (24 / ((blocksPerHour * hours) / 272)) + 1) **
        365;

      console.log("earned!");
      console.log("Overall APR:", apr * 100, "%");
      console.log("Overall APY:", (apy - 1) * 100, "%");

      console.log("earned!");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
