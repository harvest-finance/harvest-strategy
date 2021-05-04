// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

const Vault = artifacts.require("Vault");
const VaultProxy = artifacts.require("VaultProxy");
const VaultV3 = artifacts.require("VaultV3");
const IdleStrategyUSDC_BY_MainnetV3 = artifacts.require("IdleStrategyUSDC_BY_MainnetV3");
const IdleStrategyUSDC_RA_MainnetV3 = artifacts.require("IdleStrategyUSDC_RA_MainnetV3");
const SplitterProxy = artifacts.require("SplitterProxy");
const SplitterStrategy = artifacts.require("SplitterStrategy");
const SplitterStrategyWhitelist = artifacts.require("SplitterStrategyWhitelist");
const SplitterConfig = artifacts.require("SplitterConfig");
const NoopStrategyV3 = artifacts.require("NoopStrategyV3");

describe("Splitter USDC", function (){

  // external contracts
  let underlying;
  let accounts;

  // external setup
  let underlyingWhale = "0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503";

  // parties in the protocol
  let farmer1;
  let farmer2;

  // Core protocol contracts
  let vault;
  let vaultV3Implementation;

  let farmerBalance1;
  let farmerBalance2;

  let splitter;
  let strategy1, strategy2, strategy3;

  async function setupExternalContracts() {
    underlying = await IERC20.at("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");
    console.log("Fetching Underlying at: ", underlying.address);
    vault = await Vault.at("0xf0358e8c3CD5Fa238a29301d0bEa3D63A17bEdBE");
  }

  async function resetBalance() {
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await send.ether(etherGiver, underlyingWhale, "1000000000000000000");

    const allBalance = new BigNumber(await underlying.balanceOf(underlyingWhale)).dividedBy(100);
    farmerBalance1 = allBalance.dividedBy(2);
    farmerBalance2 = allBalance.minus(farmerBalance1);

    await underlying.transfer(farmer1, farmerBalance1.toFixed(), {from: underlyingWhale});
    await underlying.transfer(farmer2, farmerBalance2.toFixed(), {from: underlyingWhale});
  }

  before(async function() {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[3];
    farmer2 = accounts[4];

    // impersonate accounts
    await impersonates([governance, underlyingWhale]);

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

    strategy1 = await IdleStrategyUSDC_BY_MainnetV3.new(
      addresses.Storage,
      splitter.address,
      { from: governance }
    );

    await strategy1.setLiquidation(true, true, true, {from: governance});

    strategy2 = await IdleStrategyUSDC_RA_MainnetV3.new(
      addresses.Storage,
      splitter.address,
      { from: governance }
    );

    await strategy2.setLiquidation(true, true, true, {from: governance});

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

    await resetBalance();
  });

  async function depositVault(_farmer, _underlying, _vault, _amount) {
    await _underlying.approve(_vault.address, _amount, { from: _farmer });
    await _vault.deposit(_amount, { from: _farmer });
  }

  it("A farmer investing underlying + strategy reconfiguration", async function () {
    const vaultInitialBalanceWithInvestment = new BigNumber(await vault.underlyingBalanceWithInvestment());
    console.log("Vault initial total balance:", vaultInitialBalanceWithInvestment.toFixed());
    console.log("Vault's initial price per share:", new BigNumber(await vault.getPricePerFullShare()).toFixed());

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

    console.log("splitter set!");
    console.log("deposits began!");

    let farmer1OldBalance = new BigNumber(await underlying.balanceOf(farmer1));
    await depositVault(farmer1, underlying, vault, farmerBalance1);
    let farmer2OldBalance = new BigNumber(await underlying.balanceOf(farmer2));
    await depositVault(farmer2, underlying, vault, farmerBalance2);

    console.log("hard works!");

    await vault.doHardWork({from: governance});
    await Utils.advanceNBlock(10);

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

    await vault.doHardWork({from: governance});

    await Utils.advanceNBlock(10);
    await vault.doHardWork({from: governance});

    // Checking that farmer gained money (but WITHOUT withdrawals because the current vaults are still V3 not V3)
    const farmer1NewBalanceAfterHardwork = new BigNumber(await vault.underlyingBalanceWithInvestmentForHolder(farmer1));
    console.log("Farmer1 balance before:", farmer1OldBalance.toFixed());
    console.log("Farmer1 balance after:", farmer1NewBalanceAfterHardwork.toFixed());
    Utils.assertBNGt(farmer1NewBalanceAfterHardwork, farmer1OldBalance);

    const farmer2NewBalanceAfterHardwork = new BigNumber(await vault.underlyingBalanceWithInvestmentForHolder(farmer2));
    console.log("Farmer2 balance before:", farmer2OldBalance.toFixed());
    console.log("Farmer2 balance after:", farmer2NewBalanceAfterHardwork.toFixed());
    Utils.assertBNGt(farmer2NewBalanceAfterHardwork, farmer2OldBalance);

    // withdrawing
    console.log("Price per share before farmer1 withdrew:          ", new BigNumber(await vault.getPricePerFullShare()).toFixed());
    await vault.withdraw(new BigNumber(await vault.balanceOf(farmer1)).toFixed(), {from: farmer1});
    console.log("Price per share after farmer1 withdrew:          ", new BigNumber(await vault.getPricePerFullShare()).toFixed());
    await vault.withdraw(new BigNumber(await vault.balanceOf(farmer2)).toFixed(), {from: farmer2});
    console.log("Price per share after farmer2 withdrew:          ", new BigNumber(await vault.getPricePerFullShare()).toFixed());

    const farmer1NewBalanceAfterWithdrawal = new BigNumber(await underlying.balanceOf(farmer1));
    console.log("Farmer1 balance before withdrawal:", farmer1NewBalanceAfterHardwork.toFixed());
    console.log("Farmer1 balance after  withdrawal:", farmer1NewBalanceAfterWithdrawal.toFixed());

    const farmer2NewBalanceAfterWithdrawal = new BigNumber(await underlying.balanceOf(farmer2));
    console.log("Farmer2 balance before withdrawal:", farmer2NewBalanceAfterHardwork.toFixed());
    console.log("Farmer2 balance after  withdrawal:", farmer2NewBalanceAfterWithdrawal.toFixed());

    console.log("Vault total balance after two withdrawals", new BigNumber(await vault.underlyingBalanceWithInvestment()).toFixed());
    console.log("Price per share:          ", new BigNumber(await vault.getPricePerFullShare()).toFixed());
    console.log("strategy1 underlying:     ", new BigNumber(await strategy1.investedUnderlyingBalance()).toFixed());
    console.log("strategy2 underlying:     ", new BigNumber(await strategy2.investedUnderlyingBalance()).toFixed());
    console.log("strategy3 underlying:     ", new BigNumber(await strategy3.investedUnderlyingBalance()).toFixed());
    console.log("splitter  underlying:     ", new BigNumber(await underlying.balanceOf(splitter.address)).toFixed());
    console.log("total invested underlying:", new BigNumber(await splitter.investedUnderlyingBalance()).toFixed());
/*
    //=================
    // now, reconfiguring to withdraw everything from strategies 2 and 3 and deposit into strategy1
    // First, changing the ratios so that all new investAllUnderlying() calls would only invest in strategy1
    await splitter.reconfigureStrategies(
      [strategy1.address, strategy2.address, strategy3.address],
      ["10000", "0", "0"],
      { from: governance }
    );

    console.log("Vault total balance before moveAllAcrossStrategies", new BigNumber(await vault.underlyingBalanceWithInvestment()).toFixed());
    console.log("Price per share:          ", new BigNumber(await vault.getPricePerFullShare()).toFixed());
    console.log("strategy1 underlying:     ", new BigNumber(await strategy1.investedUnderlyingBalance()).toFixed());
    console.log("strategy2 underlying:     ", new BigNumber(await strategy2.investedUnderlyingBalance()).toFixed());
    console.log("strategy3 underlying:     ", new BigNumber(await strategy3.investedUnderlyingBalance()).toFixed());
    console.log("splitter  underlying:     ", new BigNumber(await underlying.balanceOf(splitter.address)).toFixed());
    console.log("total invested underlying:", new BigNumber(await splitter.investedUnderlyingBalance()).toFixed());

    // moving everything from strategy3 into strategy2, at once
    await splitter.moveAllAcrossStrategies(
      strategy3.address, strategy2.address,
      { from: governance }
    );

    // moving everything from strategy2 into strategy1, at once
    await splitter.moveAllAcrossStrategies(
      strategy2.address, strategy1.address,
      { from: governance }
    );

    console.log("Vault total balance  after moveAllAcrossStrategies", new BigNumber(await vault.underlyingBalanceWithInvestment()).toFixed());

    // Checking that farmer balances
    const farmer1NewBalanceAfterReconfiguration = new BigNumber(await vault.underlyingBalanceWithInvestmentForHolder(farmer1));
    console.log("Farmer1 balance before reconfiguration:", farmer1NewBalanceAfterHardwork.toFixed());
    console.log("Farmer1 balance after  reconfiguration:", farmer1NewBalanceAfterReconfiguration.toFixed());

    const farmer2NewBalanceAfterReconfiguration = new BigNumber(await vault.underlyingBalanceWithInvestmentForHolder(farmer2));
    console.log("Farmer2 balance before reconfiguration:", farmer2NewBalanceAfterHardwork.toFixed());
    console.log("Farmer2 balance after  reconfiguration:", farmer2NewBalanceAfterReconfiguration.toFixed());

    console.log("Price per share:          ", new BigNumber(await vault.getPricePerFullShare()).toFixed());
    console.log("strategy1 underlying:     ", new BigNumber(await strategy1.investedUnderlyingBalance()).toFixed());
    console.log("strategy2 underlying:     ", new BigNumber(await strategy2.investedUnderlyingBalance()).toFixed());
    console.log("strategy3 underlying:     ", new BigNumber(await strategy3.investedUnderlyingBalance()).toFixed());
    console.log("splitter  underlying:     ", new BigNumber(await underlying.balanceOf(splitter.address)).toFixed());
    console.log("total invested underlying:", new BigNumber(await splitter.investedUnderlyingBalance()).toFixed());

    // withdrawing everything from all the strategies
    await splitter.withdrawAllToVault({from: governance});

    console.log("Vault total balance after withdrawAllToVault", new BigNumber(await vault.underlyingBalanceWithInvestment()).toFixed());

    // check that the vault hasn't lost any money since the start of the test
    Utils.assertBNGt(await vault.underlyingBalanceWithInvestment(), vaultInitialBalanceWithInvestment);*/
  });
});
