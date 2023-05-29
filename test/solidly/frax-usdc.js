// Utilities
const Utils = require("../utilities/Utils.js");
const {
  impersonates,
  setupCoreProtocol,
  depositVault,
} = require("../utilities/hh-utils.js");

const BigNumber = require("bignumber.js");
const { web3 } = require("@openzeppelin/test-helpers/src/setup.js");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const Strategy = artifacts.require("SolidlyStrategyMainnet_FRAX_USDC");

//This test was developed at blockNumber 16993444

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("SolidlyStrategyMainnet_FRAX_USDC", function () {
  let accounts;

  // external contracts
  let underlying;
  let frax = "0x853d955aCEf822Db058eb8505911ED77F175b99e";
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

  // external setup
  let underlyingWhale = "0xA1eED1566F5ec6c1b3985B6fC9f101a68fDb7071";

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
    underlying = await IERC20.at("0x7d8311F7E0C1D19C1096E43E8B6C17b67Fb6AA2e");
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance() {
    let etherGiver = accounts[9];

    await web3.eth.sendTransaction({
      from: etherGiver,
      to: underlyingWhale,
      value: 10e18,
    });
    await web3.eth.sendTransaction({
      from: etherGiver,
      to: governance,
      value: 10e18,
    });

    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, {
      from: underlyingWhale,
    });
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
      liquidation: [{ uniV3: [weth, frax] }],
    });
  });

  describe("Happy path", function () {
    it("Farmer should earn money", async function () {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));

      await depositVault(farmer1, underlying, vault, farmerOldBalance);

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
        console.log(
          "growth: ",
          newSharePrice.toFixed() / oldSharePrice.toFixed()
        );

        apr =
          (newSharePrice.toFixed() / oldSharePrice.toFixed() - 1) *
          (24 / (blocksPerHour / 272)) *
          365;
        apy =
          ((newSharePrice.toFixed() / oldSharePrice.toFixed() - 1) *
            (24 / (blocksPerHour / 272)) +
            1) **
          365;

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
        (farmerNewBalance.toFixed() / farmerOldBalance.toFixed() - 1) *
        (24 / ((blocksPerHour * hours) / 272)) *
        365;
      apy =
        ((farmerNewBalance.toFixed() / farmerOldBalance.toFixed() - 1) *
          (24 / ((blocksPerHour * hours) / 272)) +
          1) **
        365;

      console.log("earned!");
      console.log("Overall APR:", apr * 100, "%");
      console.log("Overall APY:", (apy - 1) * 100, "%");

      console.log("earned!");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});