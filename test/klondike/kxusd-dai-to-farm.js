// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

//const Strategy = artifacts.require("");
const Strategy = artifacts.require("Klondike2FarmStrategyMainnet_KXUSD_DAI");
const NoMintRewardPool = artifacts.require("NoMintRewardPool");

//Run test at blockNumber 12226120

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Klondike to FARM: KXUSD/DAI", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  // block: 11920986
  let underlyingWhale = "0x4bFc3b8C82909Ad224D1E2C0305Fa5bFAB1E7f1C";

  // parties in the protocol
  let governance;
  let farmer1;

  // numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let controller;
  let vault;
  let strategy;
  let rewardPool;
  let farm, iFarm;

  async function setupExternalContracts() {
    underlying = await IERC20.at("0x672C973155c46Fc264c077a41218Ddc397bB7532");
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
      "liquidation": {
        // klon -> wbtc -> weth -> farm
        "uni": ["0xbf15797BB5E47F6fB094A4abDB2cfC43F77179Ef", "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
          "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", addresses.FARM]
      },
      "underlying": underlying,
      "governance": governance,
    });

    // Else sellfloor will not be reached
    await strategy.setSellFloor(1, {from:governance});

    // whale send underlying to farmers
    await setupBalance();

    farm = await IERC20.at(addresses.FARM);
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
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);
        let blocksPerHour = 2400;
        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log("old shareprice: ", oldSharePrice.toFixed());
        console.log("new shareprice: ", newSharePrice.toFixed());
        console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());
        console.log("iFarm in reward pool: ", (new BigNumber(await iFarm.balanceOf(rewardPool.address))).toFixed());
        await Utils.advanceNBlock(blocksPerHour);
      }
      await rewardPool.exit({from: farmer1});
      let farmerNewIFarm = new BigNumber(await iFarm.balanceOf(farmer1));
      await vault.withdraw(new BigNumber(await vault.balanceOf(farmer1)).toFixed(), { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));

      console.log("farmerNewIFarm:    ", farmerNewIFarm.toFixed());
      console.log("farmerOldBalance: ", farmerOldBalance.toFixed());
      console.log("farmerNewBalance: ", farmerNewBalance.toFixed());
      Utils.assertBNGt(farmerNewIFarm, 0);
      console.log("earned!");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
