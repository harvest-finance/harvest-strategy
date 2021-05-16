// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const { assert } = require("chai");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

//const Strategy = artifacts.require("");
const WETH9 = artifacts.require("WETH9");

//const Strategy = artifacts.require("");
const CompoundWETHFoldStrategyMainnet = artifacts.require("CompoundWETHFoldStrategyMainnet");

const Vault = artifacts.require("Vault");
const VaultProxy = artifacts.require("VaultProxy");

const VaultV3 = artifacts.require("VaultV3");
const SplitterProxy = artifacts.require("SplitterProxy");
const SplitterStrategy = artifacts.require("LiquidityProvisionSplitter");
const SplitterStrategyWhitelist = artifacts.require("SplitterStrategyWhitelist");
const SplitterConfig = artifacts.require("SplitterConfig");
const NoopStrategyV3 = artifacts.require("NoopStrategyV3");
const LiquidityRecipient = artifacts.require("LiquidityRecipient");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Splitter WETH with provision", function() {
  let accounts;

  // external contracts
  let underlying;
  let weth9;
  let farm;
  let liquidityRecipient;
  let oldLiquidityRecipient;

  // external setup
  let underlyingWhale;

  // parties in the protocol
  let governance;
  let farmer1;
  let treasury;

  // numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let vault;
  let strategy1;
  let strategy2;
  let strategy3;

  async function setupExternalContracts() {
    underlying = await IERC20.at("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
    weth9 = await WETH9.at("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
    farm = await IERC20.at("0xa0246c9032bC3A600820415aE600c6388619A14D");
    vault = await Vault.at("0xFE09e53A81Fe2808bc493ea64319109B5bAa573e"); // WETH vault
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance(){
    let etherGiver = accounts[9];

    // Give whale some ether to make sure the following actions are good
    await send.ether(etherGiver, underlyingWhale, "50" + "000000000000000000");
    await weth9.deposit({from : underlyingWhale, value: "50" + "000000000000000000"})

    // Wrap that Ether
    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, { from: underlyingWhale });
  }

  async function replenishRecipient(recipient, amount) {
    let etherGiver = accounts[9];
    await weth9.deposit({from : etherGiver, value: amount})
    await weth9.transfer(recipient, amount, {from: etherGiver});
  }

  before(async function() {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    underlyingWhale = accounts[8];
    farmer1 = accounts[1];
    treasury = accounts[2];

    // impersonate accounts
    await impersonates([governance]);

    await setupExternalContracts();

    // set up the splitter and all the strategies
    vaultV3Implementation = await VaultV3.new();

    const splitterImpl = await SplitterStrategy.new();
    const splitterProxy = await SplitterProxy.new(splitterImpl.address);
    splitter = await SplitterStrategy.at(splitterProxy.address);

    const strategyWhitelist = await SplitterStrategyWhitelist.new(splitter.address);
    const splitterConfig = await SplitterConfig.new(splitter.address);

    await splitter.initSplitter(
      addresses.Storage,
      vault.address,
      strategyWhitelist.address,
      splitterConfig.address,
      { from: governance }
    );

    // set up the strategies:
    // First IDLE strategy is set with ratio 60%
    // Second IDLE strategy is set with ratio 30%
    // NoopStrategyV3 is set with ratio 5% (just for testing)
    const investmentRatioNumerators = ["6000", "3000", "500"];

    strategy1 = await CompoundWETHFoldStrategyMainnet.new(
      addresses.Storage,
      splitter.address,
      { from: governance }
    );

    strategy2 = await CompoundWETHFoldStrategyMainnet.new(
      addresses.Storage,
      splitter.address,
      { from: governance }
    );

    strategy3 = await NoopStrategyV3.new(
      addresses.Storage,
      underlying.address,
      splitter.address,
      { from: governance }
    );

    await splitter.initStrategies(
      [strategy1.address, strategy2.address, strategy3.address],
      investmentRatioNumerators,
      // the rest stays in the splitter as cash
      { from: governance }
    );

    oldLiquidityRecipient = await LiquidityRecipient.at("0x7Bf835E8975623063E498c4CA0EA92283100F2B3");

    liquidityRecipient = await LiquidityRecipient.new(
      addresses.Storage,
      weth9.address,
      addresses.FARM,
      treasury,
      "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", //MFC.UNISWAP_V2_ROUTER02_ADDRESS,
      "0x56feAccb7f750B997B36A68625C7C596F0B41A58", //MFC.UNISWAP_ETH_FARM_LP_ADDRESS,
      splitter.address
    );

    await splitter.setLiquidityRecipient(liquidityRecipient.address, {from: governance});

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      // Replenish Balance of Liquidity Recipient
      let replenishAmount = "1500" + "0".repeat(18);
      await replenishRecipient("0x7Bf835E8975623063E498c4CA0EA92283100F2B3", replenishAmount);

      oldWethStrategy = await CompoundWETHFoldStrategyMainnet.at(await vault.strategy());
      let loanAmount = await oldWethStrategy.liquidityLoanCurrent();
      await oldWethStrategy.settleLoan(loanAmount.toString(), {from: governance});
      console.log("farm in old liquidityRecipient:", (await farm.balanceOf(oldLiquidityRecipient.address)).toString());
      await oldLiquidityRecipient.salvage(governance, farm.address, await farm.balanceOf(oldLiquidityRecipient.address), {from: governance});

      // Update to Vault V3
      // Switch to Splitter
      await vault.scheduleUpgrade(vaultV3Implementation.address, {from: governance});
      await vault.announceStrategyUpdate(splitter.address, {from: governance});
      let blocksPerHour = 240;

      console.log("waiting for strategy update...");
      for (let i = 0; i < 12; i++) {
        await Utils.advanceNBlock(blocksPerHour);
      }

      await vault.setVaultFractionToInvest(95, 100, {from: governance});
      await vault.setStrategy(splitter.address, {from: governance});

      const vaultAsProxy = await VaultProxy.at(vault.address);
      await vaultAsProxy.upgrade({from: governance});

      // invest
      await vault.doHardWork({from: governance});
      await Utils.advanceNBlock(10);

      // liquidity provisioning
      await splitter.setLiquidityRecipient(liquidityRecipient.address, {from: governance});
      await splitter.setLiquidityLoanTarget("1000" + "0".repeat(18), {from: governance});

      let pricePershareBeforeProvide = new BigNumber(await vault.getPricePerFullShare()).toFixed();
      console.log("Price per share before:    ", pricePershareBeforeProvide);
      console.log("weth in liquidityRecipient:", (await weth9.balanceOf(liquidityRecipient.address)).toString());
      console.log("farm in liquidityRecipient:", (await farm.balanceOf(liquidityRecipient.address)).toString());
      await farm.transfer(liquidityRecipient.address, await farm.balanceOf(governance), {from: governance});

      // While we've set the target to be 1000 ETH, there is not so much weth in left over.
      // this depends on the total underlying and the investment ratio
      // provide loan doesn't pull funds from the vault,
      // so we have to calculate the investment ratio, dohardwork, then provideLoan
      // to get the desired loan.

      await splitter.provideLoan({from: governance});
      assert.notEqual(await splitter.liquidityLoanCurrent(), "0");

      let pricePershareAfterProvide = new BigNumber(await vault.getPricePerFullShare()).toFixed();
      // Price per full share shouldn't change with the provide function
      assert.equal(pricePershareBeforeProvide, pricePershareAfterProvide);

      console.log("Price per share after:    ", pricePershareAfterProvide);
      console.log("weth in liquidityRecipient:", (await weth9.balanceOf(liquidityRecipient.address)).toString());
      console.log("farm in liquidityRecipient:", (await farm.balanceOf(liquidityRecipient.address)).toString());

      // do hardwork, print info
      for (let i = 0; i < 12; i++) {
        console.log("Price per share:          ", new BigNumber(await vault.getPricePerFullShare()).toFixed());
        console.log("strategy1 underlying:     ", new BigNumber(await strategy1.investedUnderlyingBalance()).toFixed());
        console.log("strategy2 underlying:     ", new BigNumber(await strategy2.investedUnderlyingBalance()).toFixed());
        console.log("strategy3 underlying:     ", new BigNumber(await strategy3.investedUnderlyingBalance()).toFixed());
        console.log("splitter  underlying:     ", new BigNumber(await underlying.balanceOf(splitter.address)).toFixed());
        console.log("total invested underlying:", new BigNumber(await splitter.investedUnderlyingBalance()).toFixed());
        await Utils.advanceNBlock(blocksPerHour);
        await vault.doHardWork({from: governance});
      }

      console.log("Settle loan ----");
      await splitter.setLiquidityLoanTarget("0", {from: governance});
      let pricePershareBeforeSettle = new BigNumber(await vault.getPricePerFullShare()).toFixed();
      await splitter.settleLoan( await splitter.liquidityLoanCurrent() , {from: governance});
      let pricePershareAfterSettle = new BigNumber(await vault.getPricePerFullShare()).toFixed();
      // Price per full share shouldn't change with the settle function
      assert.equal(pricePershareBeforeSettle, pricePershareAfterSettle);
      assert.equal(await splitter.liquidityLoanCurrent(), "0");
      console.log("Price per share:          ", new BigNumber(await vault.getPricePerFullShare()).toFixed());
      console.log("strategy1 underlying:     ", new BigNumber(await strategy1.investedUnderlyingBalance()).toFixed());
      console.log("strategy2 underlying:     ", new BigNumber(await strategy2.investedUnderlyingBalance()).toFixed());
      console.log("strategy3 underlying:     ", new BigNumber(await strategy3.investedUnderlyingBalance()).toFixed());
      console.log("splitter  underlying:     ", new BigNumber(await underlying.balanceOf(splitter.address)).toFixed());
      console.log("total invested underlying:", new BigNumber(await splitter.investedUnderlyingBalance()).toFixed());
      console.log("weth in liquidityRecipient:", (await weth9.balanceOf(liquidityRecipient.address)).toString());
      console.log("farm in liquidityRecipient:", (await farm.balanceOf(liquidityRecipient.address)).toString());
    });
  });
});
