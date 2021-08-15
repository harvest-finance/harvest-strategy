// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

const YelStrategy = artifacts.require("YelStrategyMainnet_YEL");
const YelWethStrategy = artifacts.require("YelHodlStrategyMainnet_YEL_WETH");
const IFeeRewardForwarder = artifacts.require("IFeeRewardForwarderV6");
const IOracleMainnet = artifacts.require("IOracleMainnet");

const D18 = new BigNumber(Math.pow(10, 18));

//This test was developed at blockNumber 13029225

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet YEL/WETH YEL HODL", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  let underlyingWhale = "0x1855CA2c1Bd691F0bba30303BEE8319be5e328d1";
  let yel = "0x7815bDa662050D84718B988735218CFfd32f75ea";
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let feeForwarderAddr = "0x153C544f72329c1ba521DDf5086cf2fA98C86676";
  let priceOracleAddr = "0x48DC32eCA58106f06b41dE514F29780FFA59c279";
  let priceOracle;

  let sushiDex = "0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a";
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
    underlying = await IERC20.at("0xc83cE8612164eF7A13d17DDea4271DD8e8EEbE5d");
    console.log("Fetching Underlying at: ", underlying.address);
    priceOracle = await IOracleMainnet.at(priceOracleAddr);
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
    [controller, hodlVault, hodlStrategy] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": YelStrategy,
      "strategyArtifactIsUpgradable": true,
      "underlying": await IERC20.at(yel),
      "governance": governance,
      "liquidation": [{"sushi": [yel, weth]}],
    });
    [controller, vault, strategy, potPool] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": YelWethStrategy,
      "strategyArtifactIsUpgradable": true,
      "underlying": underlying,
      "governance": governance,
      "rewardPool" : true,
      "rewardPoolConfig": {
        type: 'PotPool',
        rewardTokens: [
          addresses.IFARM,
          hodlVault.address // fYEL
        ]
      },
    });

    feeForwarder = await IFeeRewardForwarder.at(feeForwarderAddr);
    let path = [yel, weth, addresses.FARM];
    let dexes = [sushiDex, bancorDex];
    await feeForwarder.configureLiquidation(path, dexes, {from: governance});

    await strategy.setHodlVault(hodlVault.address, {from: governance});
    await strategy.setPotPool(potPool.address, {from: governance});
    await potPool.setRewardDistribution([strategy.address], true, {from: governance});
    await controller.addToWhitelist(strategy.address, {from: governance});

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      let farmerOldFYel = new BigNumber(await hodlVault.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);
      let fTokenBalance = new BigNumber(await vault.balanceOf(farmer1));

      let erc20Vault = await IERC20.at(vault.address);
      await erc20Vault.approve(potPool.address, fTokenBalance, {from: farmer1});
      await potPool.stake(fTokenBalance, {from: farmer1});

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let blocksPerHour = 2400;
      let oldSharePrice;
      let newSharePrice;
      let oldHodlSharePrice;
      let newHodlSharePrice;
      let oldPotPoolBalance;
      let newPotPoolBalance;
      let yelPrice;
      let lpPrice;
      let oldValue;
      let newValue;
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);

        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        oldHodlSharePrice = new BigNumber(await hodlVault.getPricePerFullShare());
        oldPotPoolBalance = new BigNumber(await hodlVault.balanceOf(potPool.address));
        await controller.doHardWork(vault.address, {from: governance});
        await controller.doHardWork(hodlVault.address, {from: governance});
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());
        newHodlSharePrice = new BigNumber(await hodlVault.getPricePerFullShare());
        newPotPoolBalance = new BigNumber(await hodlVault.balanceOf(potPool.address));

        yelPrice = new BigNumber(await priceOracle.getPrice(yel));
        lpPrice = new BigNumber(await priceOracle.getPrice(underlying.address));
        console.log("YEL price:", yelPrice.toFixed()/D18.toFixed());
        console.log("LP price:", lpPrice.toFixed()/D18.toFixed());

        oldValue = (fTokenBalance.times(oldSharePrice).times(lpPrice)).div(1e36).plus((oldPotPoolBalance.times(oldHodlSharePrice).times(yelPrice)).div(1e36));
        newValue = (fTokenBalance.times(newSharePrice).times(lpPrice)).div(1e36).plus((newPotPoolBalance.times(newHodlSharePrice).times(yelPrice)).div(1e36));

        console.log("old value: ", oldValue.toFixed()/D18.toFixed());
        console.log("new value: ", newValue.toFixed()/D18.toFixed());
        console.log("growth: ", newValue.toFixed() / oldValue.toFixed());

        console.log("fYEL in potpool: ", newPotPoolBalance.toFixed());

        apr = (newValue.toFixed()/oldValue.toFixed()-1)*(24/(blocksPerHour/272))*365;
        apy = ((newValue.toFixed()/oldValue.toFixed()-1)*(24/(blocksPerHour/272))+1)**365;

        console.log("instant APR:", apr*100, "%");
        console.log("instant APY:", (apy-1)*100, "%");

        await Utils.advanceNBlock(blocksPerHour);
      }
      // withdrawAll to make sure no doHardwork is called when we do withdraw later.
      await vault.withdrawAll({ from: governance });

      // wait until all reward can be claimed by the farmer
      await Utils.waitTime(86400 * 30 * 1000);
      console.log("vaultBalance: ", fTokenBalance.toFixed());
      await potPool.exit({from: farmer1});
      await vault.withdraw(fTokenBalance.toFixed(), { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      let farmerNewFYel = new BigNumber(await hodlVault.balanceOf(farmer1));
      Utils.assertBNEq(farmerNewBalance, farmerOldBalance);
      Utils.assertBNGt(farmerNewFYel, farmerOldFYel);

      oldValue = (fTokenBalance.times(1e18).times(lpPrice)).div(1e36);
      newValue = (fTokenBalance.times(newSharePrice).times(lpPrice)).div(1e36).plus((farmerNewFYel.times(newHodlSharePrice).times(yelPrice)).div(1e36));

      apr = (newValue.toFixed()/oldValue.toFixed()-1)*(24/(blocksPerHour*hours/272))*365;
      apy = ((newValue.toFixed()/oldValue.toFixed()-1)*(24/(blocksPerHour*hours/272))+1)**365;

      console.log("Overall APR:", apr*100, "%");
      console.log("Overall APY:", (apy-1)*100, "%");

      console.log("potpool totalShare: ", (new BigNumber(await potPool.totalSupply())).toFixed());
      console.log("fYEL in potpool: ", (new BigNumber(await hodlVault.balanceOf(potPool.address))).toFixed() );
      console.log("Farmer got fYEL from potpool: ", farmerNewFYel.toFixed());
      console.log("earned!");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
