// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault, setupFactory } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send, expectRevert } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const IWETH = artifacts.require("IWETH");
const PotPool = artifacts.require("PotPool");

const SampleUpgradableStrategy = artifacts.require("YelStrategyMainnet_YEL_WETH");
const IController = artifacts.require("IController");
const IStrategy = artifacts.require("IStrategy");
const IVault = artifacts.require("IVault");
const IdleStrategyWETHMainnet = artifacts.require("IdleStrategyWETHMainnet");

const testUniV3PositionId = 82734;

// block number: 13639563
describe("Factory", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  let underlyingWhale = "0x78A97188707a808044f0d3193af9b71254781CF8";

  // parties in the protocol
  let governance;
  let farmer1;
  let weth;

  // numbers used in tests
  let farmerBalance;
  let farmerWethBalance;

  // Core protocol contracts
  let controller;
  let factory;
  let vault;
  let strategy;
  let pool;

  async function setupExternalContracts() {
    underlying = await IERC20.at("0xc83cE8612164eF7A13d17DDea4271DD8e8EEbE5d");
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance(){
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await web3.eth.sendTransaction({ from: etherGiver, to: underlyingWhale, value: 10e18});
    await web3.eth.sendTransaction({ from: etherGiver, to: governance, value: 10e18});

    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, { from: underlyingWhale });

    farmerWethBalance = String(7 * 10e18);
    weth = await IWETH.at(addresses.WETH);
    await weth.deposit({ value: farmerWethBalance, from: farmer1 });
  }

  before(async function() {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale]);
    await setupExternalContracts();

    // whale send underlying to farmers
    await setupBalance();

    controller = await IController.at(addresses.Controller);
    [factory] = await setupFactory();
  });

  describe("Happy path", function() {
    it("Should deploy a working vault with upgradable strategy", async function() {
      await factory.createRegularVaultUsingUpgradableStrategy("mock-upgradable", underlying.address, (await SampleUpgradableStrategy.new()).address);
      const deployed = await factory.completedDeployments("mock-upgradable");
      vault = await IVault.at(deployed.NewVault);
      pool = await PotPool.at(deployed.NewPool);
      strategy = await IStrategy.at(deployed.NewStrategy);

      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);
      let fTokenBalance = await vault.balanceOf(farmer1);

      await (await IERC20.at(vault.address)).approve(pool.address, fTokenBalance, {from: farmer1});
      await pool.stake(fTokenBalance, {from: farmer1}); // this checks that pool is matching
      await pool.exit({from: farmer1}); // this checks that pool is matching

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 3;
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

        apr = (newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))*365;
        apy = ((newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))+1)**365;

        console.log("instant APR:", apr*100, "%");
        console.log("instant APY:", (apy-1)*100, "%");

        await Utils.advanceNBlock(blocksPerHour);
      }
      await vault.withdraw(fTokenBalance, { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      Utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      apr = (farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))*365;
      apy = ((farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))+1)**365;

      console.log("earned!");
      console.log("Overall APR:", apr*100, "%");
      console.log("Overall APY:", (apy-1)*100, "%");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });

    it("Should deploy a working vault with a non-upgradable strategy added to it later", async function() {
      farmerBalance = farmerWethBalance; // using WETH
      underlying = await IERC20.at(weth.address);

      await factory.createRegularVault("mock-regular", addresses.WETH);
      const deployed = await factory.completedDeployments("mock-regular");
      vault = await IVault.at(deployed.NewVault);
      pool = await PotPool.at(deployed.NewPool);
      await vault.setStrategy((await IdleStrategyWETHMainnet.new(addresses.Storage, vault.address)).address);

      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);
      let fTokenBalance = await vault.balanceOf(farmer1);

      await (await IERC20.at(vault.address)).approve(pool.address, fTokenBalance, {from: farmer1});
      await pool.stake(fTokenBalance, {from: farmer1}); // this checks that pool is matching
      await pool.exit({from: farmer1}); // this checks that pool is matching

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 3;
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

        apr = (newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))*365;
        apy = ((newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))+1)**365;

        console.log("instant APR:", apr*100, "%");
        console.log("instant APY:", (apy-1)*100, "%");

        await Utils.advanceNBlock(blocksPerHour);
      }
      await vault.withdraw(fTokenBalance, { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      Utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      apr = (farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))*365;
      apy = ((farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))+1)**365;

      console.log("earned!");
      console.log("Overall APR:", apr*100, "%");
      console.log("Overall APY:", (apy-1)*100, "%");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });

    it("Should deploy a working UNIV3 vault (when unauthorized)", async function() {
      await expectRevert(
        factory.createUniV3Vault("mock-uniV3", testUniV3PositionId, {from: farmer1}),
        "unauthorized deployer"
      );

      await factory.setAuthorization(farmer1, true);

      await factory.createUniV3Vault("mock-uniV3", testUniV3PositionId, {from: farmer1});
      const deployed = await factory.completedDeployments("mock-uniV3");
      vault = await IVault.at(deployed.NewVault);
      pool = await PotPool.at(deployed.NewPool);
      console.log("success!", vault.address);

      await factory.setAuthorization(farmer1, false);

      await expectRevert(
        factory.createUniV3Vault("mock-uniV3", testUniV3PositionId),
        "cannot reuse id"
      );

      await expectRevert(
        factory.createUniV3Vault("mock-uniV3_2", testUniV3PositionId, {from: farmer1}),
        "unauthorized deployer"
      );
    });
  });
});
