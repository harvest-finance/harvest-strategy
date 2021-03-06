// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

//const Strategy = artifacts.require("");
const Strategy = artifacts.require("FloatStrategyETHMainnet");
const RewardPool = artifacts.require("NoMintRewardPool");
const IFeeRewardForwarder = artifacts.require("IFeeRewardForwarderV6");

//Test develloped on blockNumber 12083305

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Float ETH", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  let underlyingWhale = "0x0092081d8e3e570e9e88f4563444bd4b92684502";
  let rewardDistribution = "0x383dF49ad1f0219759a46399fE33Cb7A63cd051c";
  let bankWhale = "0x1512c7c4a4266dc9a56b1f21c8cb19e13410e684";
  let poolAddr = "0x5Cc2dB43F9c2E2029AEE159bE60A9ddA50b05D4A";
  let feeForwarderAddr = "0x153C544f72329c1ba521DDf5086cf2fA98C86676";

  // parties in the protocol
  let governance;
  let farmer1;

  // numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let controller;
  let vault;
  let strategy;

  let bank = "0x24A6A37576377F63f194Caa5F518a60f45b42921";
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

  let sushiDex = "0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a";
  let uniDex = "0xde2d1a51640f78257713031680d1f306297d957426e912ab21317b9cc9495a41";

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

  async function distributeReward(){
    let etherGiver = accounts[9];
    let bankToken = await IERC20.at(bank);
    let rewardPool = await RewardPool.at(poolAddr);
    // Give whale some ether to make sure the following actions are good
    await send.ether(etherGiver, bankWhale, "1" + "000000000000000000");
    await bankToken.transfer(rewardPool.address, "875" + "000000000000000000", { from: bankWhale});

    await rewardPool.notifyRewardAmount("875" + "000000000000000000", { from: rewardDistribution});
  }

  before(async function() {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale, rewardDistribution, bankWhale]);

    await setupExternalContracts();
    [controller, vault, strategy] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": Strategy,
      "underlying": underlying,
      "governance": governance,
      "liquidation": [{"sushi": [bank, weth]}]
    });

    feeForwarder = await IFeeRewardForwarder.at(feeForwarderAddr);

    let path = [bank, weth, addresses.FARM];
    let dexes = [sushiDex, uniDex];

    await feeForwarder.configureLiquidation(path, dexes, { from: governance });

    // whale send underlying to farmers
    await setupBalance();

    await distributeReward();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
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
