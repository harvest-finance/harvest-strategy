// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

const Strategy = artifacts.require("AlkemiStrategyMainnet_WETH");
const IFeeRewardForwarder = artifacts.require("IFeeRewardForwarderV6");
const IUniV3Dex = artifacts.require("IUniV3Dex");

//This test was developed at blockNumber 13294925

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Alkemi WETH", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  let underlyingWhale = "0x0E9AED5c7721c642A032812C2c4816f7d6cB87d7";
  let alk = "0x6C16119B20fa52600230F074b349dA3cb861a7e3";
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let hodlVault = "0xF49440C1F012d041802b25A73e5B0B9166a75c02";
  let feeForwarderAddr = "0x153C544f72329c1ba521DDf5086cf2fA98C86676";
  let uniV3DexAddr = "0x1D35ba854575B576B3C0aB4e64E27Bf2D2c1D48A";
  let uniV3Dex = "0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f";
  let bancorDex = "0x4bf11b89310db45ea1467e48e832606a6ec7b8735c470fff7cf328e182a7c37e";

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
    underlying = await IERC20.at("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance(){
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await web3.eth.sendTransaction({ from: etherGiver, to: underlyingWhale, value: 1e18});

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
    [controller, vault, strategy] = await setupCoreProtocol({
      "existingVaultAddress": "0xFE09e53A81Fe2808bc493ea64319109B5bAa573e",
      "strategyArtifact": Strategy,
      "strategyArtifactIsUpgradable": true,
      "announceStrategy": true,
      "underlying": underlying,
      "governance": governance,
      "liquidation": [{"uniV3": [alk, weth]}],
    });

    feeForwarder = await IFeeRewardForwarder.at(feeForwarderAddr);
    let path = [alk, weth, addresses.FARM];
    let dexes = [uniV3Dex, bancorDex];
    await feeForwarder.configureLiquidation(path, dexes, { from: governance });

    uniV3Dex = await IUniV3Dex.at(uniV3DexAddr);
    await uniV3Dex.setFee(alk, weth, 10000, {from: governance});

    await strategy.setSellFloor(0, {from:governance});

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);
      let fTokenBalance = await vault.balanceOf(farmer1);
      let alkToken = await IERC20.at(alk);
      let hodlOldBalance = new BigNumber(await alkToken.balanceOf(hodlVault));

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let blocksPerHour = 100;
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

      let hodlNewBalance = new BigNumber(await alkToken.balanceOf(hodlVault));
      console.log("ALK before", hodlOldBalance.toFixed());
      console.log("ALK after ", hodlNewBalance.toFixed());
      Utils.assertBNGt(hodlNewBalance, hodlOldBalance);

      apr = (farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))*365;
      apy = ((farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))+1)**365;

      console.log("earned!");
      console.log("Overall APR:", apr*100, "%");
      console.log("Overall APY:", (apy-1)*100, "%");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
