// Utilities
const Utils = require("../../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../../utilities/hh-utils.js");

const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const IBooster = artifacts.require("IBooster");

const boosterAddress = "0xF403C135812408BFbE8713b5A23a04b3D48AAE31";
const hodlVault = "0xF49440C1F012d041802b25A73e5B0B9166a75c02";
const crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";

class ConvexULTest {
    constructor(){}

    async setupTest (underlyingAddress, underlyingWhale, liquidationPaths, strategyArtifact) {
        this.accounts = await web3.eth.getAccounts();
        this.farmer1 = this.accounts[1];
    
        // impersonate accounts
        await impersonates([governance, underlyingWhale]);
        await web3.eth.sendTransaction({ from: this.accounts[8], to: governance, value: 10e18});
        await web3.eth.sendTransaction({ from: this.accounts[7], to: governance, value: 10e18});
    
        await this.setupExternalContracts(underlyingAddress);

        [this.controller, this.vault, this.strategy] = await setupCoreProtocol({
            "strategyArtifact": strategyArtifact,
            "strategyArtifactIsUpgradable": true,
            "underlying": this.underlying,
            "governance": governance,
            "liquidation": liquidationPaths,
        });
    
        await strategy.setSellFloor(0, {from:governance});
    
        this.booster = await IBooster.at(boosterAddress);
    
        // whale send underlying to farmers
        await this.setupBalance(underlyingWhale);

        return {
            controller: this.controller,
            vault: this.vault,
            strategy: this.strategy,
            governance: governance
        }
    }
    
    async testHappyPath () {
        const farmerOldBalance = new BigNumber(await this.underlying.balanceOf(this.farmer1));
        await depositVault(this.farmer1, this.underlying, this.vault, this.farmerBalance);
        const fTokenBalance = await this.vault.balanceOf(this.farmer1);
        const cvxToken = await IERC20.at(cvx);
        const hodlOldBalance = new BigNumber(await cvxToken.balanceOf(hodlVault));
    
        // Using half days is to simulate how we doHardwork in the real world
        const hours = 10;
        const blocksPerHour = 2400;
        let oldSharePrice, newSharePrice, apr, apy;
        for (let i = 0; i < hours; i++) {
            console.log("loop ", i);
        
            await this.booster.earmarkRewards(await this.strategy.poolId());
        
            oldSharePrice = new BigNumber(await this.vault.getPricePerFullShare());
            await this.controller.doHardWork(this.vault.address, { from: governance });
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
        await this.vault.withdraw(fTokenBalance, { from: this.farmer1 });
        const farmerNewBalance = new BigNumber(await this.underlying.balanceOf(this.farmer1));
        Utils.assertBNGt(farmerNewBalance, farmerOldBalance);
    
        const hodlNewBalance = new BigNumber(await cvxToken.balanceOf(hodlVault));
        console.log("CVX before", hodlOldBalance.toFixed());
        console.log("CVX after ", hodlNewBalance.toFixed());
        Utils.assertBNGt(hodlNewBalance, hodlOldBalance);
    
        apr = (farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))*365;
        apy = ((farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))+1)**365;
    
        console.log("earned!");
        console.log("Overall APR:", apr*100, "%");
        console.log("Overall APY:", (apy-1)*100, "%");
    
        await this.strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    } 

    async setupExternalContracts(underlying) {
        this.underlying = await IERC20.at(underlying);
        console.log("Fetching Underlying at: ", this.underlying.address);
    }

    async setupBalance(underlyingWhale){
        let etherGiver = this.accounts[9];
        // Give whale some ether to make sure the following actions are good
        await web3.eth.sendTransaction({ from: etherGiver, to: underlyingWhale, value: 1e18});

        this.farmerBalance = await this.underlying.balanceOf(underlyingWhale);
        await this.underlying.transfer(this.farmer1, this.farmerBalance, { from: underlyingWhale });
    }
}

module.exports = { ConvexULTest };