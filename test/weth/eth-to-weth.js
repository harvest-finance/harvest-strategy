// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send, time } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const { assert } = require("chai");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

const VaultWeth = artifacts.require("VaultWeth");
const VaultProxy = artifacts.require("VaultProxy");

//This test was developed at blockNumber 11925000

describe("WETH vault upgrade: ETH to WETH", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup, block: 12656625
  let underlyingWhale = "0x4a18a50a8328b42773268b4b436254056b7d70ce";

  // parties in the protocol
  let governance;
  let farmer1;

  // numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let controller;
  let newVaultImplementation;
  let vault;
  let vaultAsProxy;
  let strategy;

  async function setupExternalContracts() {
    underlying = await IERC20.at("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
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
    farmer2 = accounts[2];

    // impersonate accounts
    await impersonates([governance, underlyingWhale]);
    await setupExternalContracts();
    newVaultImplementation = await VaultWeth.new();
    vaultAsProxy = await VaultProxy.at("0xFE09e53A81Fe2808bc493ea64319109B5bAa573e");
    vault = await VaultWeth.at("0xFE09e53A81Fe2808bc493ea64319109B5bAa573e");
  });

  describe("Happy path", function() {
    it("Farmer should get shares by depositing ETH", async function() {
      let farmerDepositValue = "10" + "000000000000000000";

      let referenceFarmer = accounts[4];
      await send.ether(accounts[9], underlyingWhale, "10" + "000000000000000000");
      await underlying.transfer(referenceFarmer, farmerDepositValue, {from: underlyingWhale});
      await underlying.approve(vault.address, farmerDepositValue, {from: referenceFarmer});
      await vault.deposit(farmerDepositValue, {from: referenceFarmer});
      let referenceShares = await vault.balanceOf(referenceFarmer);

      // #Vault upgrading to the new Implementation
      await vault.scheduleUpgrade(newVaultImplementation.address, {from: governance});
      // wait 1 day to pass timelock
      await time.increase(86400);
      await vaultAsProxy.upgrade({from: governance});

      await vault.deposit(farmerDepositValue, {from: farmer1, value: farmerDepositValue});
      let farmer1Shares = await vault.balanceOf(farmer1);

      let farmer2 = accounts[2];
      await underlying.transfer(farmer2, farmerDepositValue, {from: underlyingWhale});
      await underlying.approve(vault.address, farmerDepositValue, {from: farmer2});
      await vault.deposit(farmerDepositValue, {from: farmer2});
      let farmer2Shares = await vault.balanceOf(farmer2);

      await Utils.assertBNEq(farmer1Shares, referenceShares);
      await Utils.assertBNEq(farmer2Shares, referenceShares);

    });
  });
});
