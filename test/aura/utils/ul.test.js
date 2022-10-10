const config = require('../import/ul.config.json');

// Utilities
const Utils = require("../../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../../utilities/hh-utils.js");

const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const IAuraBooster = artifacts.require("contracts/strategies/aura/interface/IAuraBooster.sol:IAuraBooster");
const IBalancerDex = artifacts.require("contracts/base/interface/IBalancerDex.sol:IBalancerDex");

class AuraULTest {
    constructor() {
        // External Protocal Contracts
        this.underlying, this.booster;

        // Parties in the Harvest Protocol
        this.accounts;
        this.governance = config.harvestGovernance;
        this.farmer = [];
        this.farmerBalance = [];

        // Core Harvest Protocol Contracts
        this.controller, this.vault, this.strategy, this.balancerDex;
    }
    
    async setupExternalContracts(underlying) {
        this.underlying = await IERC20.at(underlying);
        console.log("Fetching Underlying at: ", this.underlying.address);
    }

    async setupLiquidationPath(setLiquidationList) {
        for (let i = 0; i < setLiquidationList.length; i++) {
            const setupInfo = setLiquidationList[i];
            const dex = await IBalancerDex.at(setupInfo.dex);
            await dex.changePoolId(setupInfo.token0, setupInfo.token1, setupInfo.poolId, {from: setupInfo.dexOwner});
            console.log("Set Dex Complete: Pair", i);
        }
    }

    async setupBalance(underlyingWhale){
        let etherGiver = this.accounts[9];
        // Give whale some ether to make sure the following actions are good
        await web3.eth.sendTransaction({ from: etherGiver, to: underlyingWhale, value: 1e18});

        this.farmerBalance[0] = await this.underlying.balanceOf(underlyingWhale);
        await this.underlying.transfer(this.farmer[0], this.farmerBalance[0], { from: underlyingWhale });
    }

    async setupTest (underlyingAddress, underlyingWhale, registryLiquidationPaths, dexLiquidationPaths, strategyArtifact) {
        this.accounts = await web3.eth.getAccounts();
        this.farmer[0] = this.accounts[1];
    
        // impersonate accounts
        let dexOwners = dexLiquidationPaths.map(i => i.dexOwner);
        await impersonates([this.governance, underlyingWhale, ...[...new Set(dexOwners)]]);
        await web3.eth.sendTransaction({ from: this.accounts[8], to: this.governance, value: 10e18});
        await web3.eth.sendTransaction({ from: this.accounts[7], to: this.governance, value: 10e18});
    
        await this.setupExternalContracts(underlyingAddress);
        await this.setupLiquidationPath(dexLiquidationPaths);

        [this.controller, this.vault, this.strategy] = await setupCoreProtocol({
            "strategyArtifact": strategyArtifact,
            "strategyArtifactIsUpgradable": true,
            "underlying": this.underlying,
            "governance": this.governance,
            "liquidation": registryLiquidationPaths,
        });
    
        await strategy.setSellFloor(0, {from: this.governance});
    
        this.booster = await IAuraBooster.at(config.booster);
    
        // whale send underlying to farmers
        await this.setupBalance(underlyingWhale);

        return {
            controller: this.controller,
            vault: this.vault,
            strategy: this.strategy,
            governance: this.governance
        }
    }
    
    async testHappyPath (rewardTokenAddress, withBooster) {
        let farmerOldBalance = new BigNumber(await this.underlying.balanceOf(this.farmer[0]));
        await depositVault(this.farmer[0], this.underlying, vault, this.farmerBalance[0]);
        let fTokenBalance = await vault.balanceOf(this.farmer[0]);
        let rewardToken = await IERC20.at(rewardTokenAddress);
        let hodlOldBalance = new BigNumber(await rewardToken.balanceOf(config.harvestHodlVault));
  
        // Using half days is to simulate how we doHardwork in the real world
        let hours = 10;
        let blocksPerHour = 2400;
        let oldSharePrice, newSharePrice, apr, apy;
        for (let i = 0; i < hours; i++) {
          console.log("loop ", i);

          if (withBooster) {
            await this.booster.earmarkRewards(await this.strategy.auraPoolId());
            console.log("collected!");
          }
  
          oldSharePrice = new BigNumber(await this.vault.getPricePerFullShare());
          await controller.doHardWork(this.vault.address, { from: this.governance });
          newSharePrice = new BigNumber(await this.vault.getPricePerFullShare());
  
          console.log("old shareprice: ", oldSharePrice.toFixed());
          console.log("new shareprice: ", newSharePrice.toFixed());
          console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());
  
          apr = (newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))*365;
          apy = ((newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))+1)**365;
  
          console.log("instant APR:", apr*100, "%");
          console.log("instant APY:", (apy-1)*100, "%");
  
          await Utils.advanceNBlock(blocksPerHour);
        }
        await this.vault.withdraw(fTokenBalance, { from: this.farmer[0] });
        let farmerNewBalance = new BigNumber(await this.underlying.balanceOf(this.farmer[0]));
        Utils.assertBNGt(farmerNewBalance, farmerOldBalance);
  
        let hodlNewBalance = new BigNumber(await rewardToken.balanceOf(config.harvestHodlVault));
        console.log("Reward Token before", hodlOldBalance.toFixed());
        console.log("Reward Token after ", hodlNewBalance.toFixed());
        Utils.assertBNGt(hodlNewBalance, hodlOldBalance);
  
        apr = (farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))*365;
        apy = ((farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))+1)**365;
  
        console.log("earned!");
        console.log("Overall APR:", apr*100, "%");
        console.log("Overall APY:", (apy-1)*100, "%");
  
        await this.strategy.withdrawAllToVault({ from: this.governance }); // making sure can withdraw all for a next switch
    }
}

module.exports = { AuraULTest };