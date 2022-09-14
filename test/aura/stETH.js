// Utilities
const addresses = require("../test-config.js");
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const IAuraBooster = artifacts.require("contracts/strategies/aura/interface/IAuraBooster.sol:IAuraBooster");
const IBalancerDex = artifacts.require("contracts/base/interface/IBalancerDex.sol:IBalancerDex");

const config = require('./import/stETH.config.json');
const Strategy = artifacts.require("AuraStrategystETH");

//This test was developed at blockNumber 13727630

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Aura auraB-stETH-STABLE pool", function() {
  // External Protocal Contracts
  let underlying, booster;

  // Parties in the Harvest Protocol
  let accounts;
  let governance = config.harvestGovernance;
  let farmer = [];
  let farmerBalance = [];

  // Core Harvest Protocol Contracts
  let controller, vault, strategy, balancerDex;

  async function setupExternalContracts() {
    underlying = await IERC20.at(config.lpTokens.B_stETH_STABLE.address);
    console.log("Fetching Underlying at: ", underlying.address);

    balancerDex = await IBalancerDex.at(config.balancerDex);
    for (let i = 0; i < config.setBalancerDex.length; i++) {
      const swapInfo = config.setBalancerDex[i];
      await balancerDex.changePoolId(swapInfo.token0, swapInfo.token1, swapInfo.poolId, {from: config.balancerDexOwner});
      console.log("Set Dex Complete: Pair", i);
    }
  }

  async function setupBalance(){
    let etherFaucet = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await web3.eth.sendTransaction({ from: etherFaucet, to: config.lpTokens.B_stETH_STABLE.whale, value: 1e18});

    farmerBalance[0] = await underlying.balanceOf(config.lpTokens.B_stETH_STABLE.whale);
    await underlying.transfer(farmer[0], farmerBalance[0], { from: config.lpTokens.B_stETH_STABLE.whale });
  }

  before(async function() {

    accounts = await web3.eth.getAccounts();
    farmer[0] = accounts[1];

    // impersonate accounts
    await impersonates([governance, config.lpTokens.B_stETH_STABLE.whale, config.balancerDexOwner]);

    const strategyArgs = [
      addresses.Storage, 
      config.lpTokens.B_stETH_STABLE.address, 
      "vaultAddr",
      config.rewardPool,
      new BigNumber(config.auraPoolId),
      config.balancerPoolId,
      config.relatedTokens.wETH,
      config.depositArrayPosition,
      config.balancerVault,
      [config.relatedTokens.wstETH, config.relatedTokens.wETH],
      config.hodlRatio
    ]

    await setupExternalContracts();
    [controller, vault, strategy] = await setupCoreProtocol({
      "strategyArtifact": Strategy,
      "strategyArtifactIsUpgradable": true,
      "underlying": underlying,
      "governance": governance,
      "liquidation": [{"balancer": [config.relatedTokens.aura, config.relatedTokens.wETH]}],
      "strategyArgs": strategyArgs
    });

    await strategy.setSellFloor(0, {from:governance});

    booster = await IAuraBooster.at(config.booster);

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer[0]));
      await depositVault(farmer[0], underlying, vault, farmerBalance[0]);
      let fTokenBalance = await vault.balanceOf(farmer[0]);
      let auraToken = await IERC20.at(config.relatedTokens.aura);
      let hodlOldBalance = new BigNumber(await auraToken.balanceOf(config.harvestHodlVault));

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let blocksPerHour = 2400;
      let oldSharePrice;
      let newSharePrice;
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);

        await booster.earmarkRewards(await strategy.auraPoolId());
        console.log("collected!");

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
      await vault.withdraw(fTokenBalance, { from: farmer[0] });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer[0]));
      Utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      let hodlNewBalance = new BigNumber(await auraToken.balanceOf(config.harvestHodlVault));
      console.log("AURA before", hodlOldBalance.toFixed());
      console.log("AURA after ", hodlNewBalance.toFixed());
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
