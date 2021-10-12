// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

const BProtocolHodlStrategyMainnet_LUSD = artifacts.require("BProtocolHodlStrategyMainnet_LUSD");
const IFeeRewardForwarder = artifacts.require("IFeeRewardForwarderV6");
const IVault = artifacts.require("IVault");

const ethers = require('ethers');

let provider = ethers.getDefaultProvider();

// This test was developed at blockNumber 13392555

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet BProtocol LUSD HODL", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  const underlyingWhale = "0xD505FcE5cd73172F748a14FA7113696418362E97";
  const lusd = "0x5f98805A4E8be255a32880FDeC7F6728C6568bA0";
  const lqty = "0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D";
  const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const feeForwarderAddr = "0x153C544f72329c1ba521DDf5086cf2fA98C86676";

  const uniV3Dex = "0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f";
  const bancorDex = "0x4bf11b89310db45ea1467e48e832606a6ec7b8735c470fff7cf328e182a7c37e";

  // parties in the protocol
  let governance;
  let farmer1;

  // numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let controller;
  let feeForwarder;
  let vault;
  let hodlVault;
  let strategy;
  let potPool;

  async function setupExternalContracts() {
     // single asset staking -> underlying is lusd
    underlying = await IERC20.at(lusd);
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

    hodlVault = await IVault.at("0xCf16b17A215D1728b0a36a30A57BeAaf7845F334");

    [controller, vault, strategy, potPool] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": BProtocolHodlStrategyMainnet_LUSD,
      "strategyArtifactIsUpgradable": true,
      "underlying": underlying,
      "governance": governance,
      "liquidation": [{'uniV3': [weth, lqty]}, {'uniV3': [lqty, weth]}],
      "rewardPool" : true,
      "rewardPoolConfig": {
        type: 'PotPool',
        rewardTokens: [
          hodlVault.address // fLQTY
        ]
      },
    });

    feeForwarder = await IFeeRewardForwarder.at(feeForwarderAddr);
    let path = [lqty, weth, addresses.FARM];
    let dexes = [uniV3Dex, bancorDex];
    await feeForwarder.configureLiquidation(path, dexes, {from: governance});
    await controller.setFeeRewardForwarder(feeForwarderAddr, {from: governance});

    await strategy.setPotPool(potPool.address, {from: governance});

    await potPool.setRewardDistribution([strategy.address], true, {from: governance});
    await controller.addToWhitelist(strategy.address, {from: governance});

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      let farmerOldFLqty = new BigNumber(await hodlVault.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);
      let fTokenBalance = new BigNumber(await vault.balanceOf(farmer1)); // fB.AMM LUSD-ETH

      let erc20Vault = await IERC20.at(vault.address);
      await erc20Vault.approve(potPool.address, fTokenBalance, {from: farmer1});
      await potPool.stake(fTokenBalance, {from: farmer1});

      console.log('farmerOldBalance', farmerOldBalance.toString());
      console.log('farmerOldFLqty', farmerOldFLqty.toString());
      console.log('in vault deposited B.AMM LUSD-ETH', new BigNumber(await vault.balanceOf(farmer1)).toFixed());
      console.log('in potPool deposited fB.AMM LUSD-ETH', new BigNumber(await potPool.balanceOf(farmer1)).toFixed());

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let blocksPerHour = 2400;
      let oldSharePrice;
      let newSharePrice;
      let oldFLqtyBalance;
      let newFLqtyBalance;
      let oldPotPoolBalance;
      let newPotPoolBalance;
      let oldRewardPoolLusdBalance;
      let newRewardPoolLusdBalance;
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

        console.log("oldHodlSharePrice: ", oldHodlSharePrice.toFixed());
        console.log("newHodlSharePrice: ", newHodlSharePrice.toFixed());
        
        console.log("old shareprice: ", oldSharePrice.toFixed());
        console.log("new shareprice: ", newSharePrice.toFixed());
        console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());

        apr = (newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))*365;
        apy = ((newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))+1)**365;

        console.log("instant APR:", apr*100, "%");
        console.log("instant APY:", (apy-1)*100, "%");

        console.log("fLQTY in potpool: ", newPotPoolBalance.toFixed());
        console.log('reward pool LUSD balance', new BigNumber(await strategy.rewardPoolLusdBalance()).toFixed());
        // console.log('in potPool deposited fB.AMM LUSD-ETH', new BigNumber(await potPool.balanceOf(farmer1)).toFixed());

        await Utils.advanceNBlock(blocksPerHour);
      }

      console.log("in vault deposited B.AMM LUSD-ETH after: ", new BigNumber(await vault.balanceOf(farmer1)).toFixed());

      // wait until all reward can be claimed by the farmer
      await Utils.waitTime(86400 * 30 * 1000);
      // withdrawAll to make sure no doHardwork is called when we do withdraw later.
      await vault.withdrawAll({ from: governance });

      await Utils.advanceNBlock(1);

      console.log('in potPool deposited fB.AMM LUSD-ETH after', new BigNumber(await potPool.balanceOf(farmer1)).toFixed());
      await potPool.exit({from: farmer1});
      console.log('in potPool deposited fB.AMM LUSD-ETH after exit', new BigNumber(await potPool.balanceOf(farmer1)).toFixed());
      console.log("in vault deposited B.AMM LUSD-ETH after: ", new BigNumber(await vault.balanceOf(farmer1)).toFixed());
      await vault.withdraw(new BigNumber(await vault.balanceOf(farmer1)).toFixed(), { from: farmer1 });

      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      console.log('farmerOldBalance LUSD', farmerOldBalance.toFixed());
      console.log('farmerNewBalance LUSD', farmerNewBalance.toFixed());
      let farmerNewFLqty = new BigNumber(await hodlVault.balanceOf(farmer1));
      // Utils.assertBNEq(farmerNewBalance, farmerOldBalance);
      Utils.assertBNGt(farmerNewFLqty, farmerOldFLqty);

      console.log("farmer had fLQTY before", farmerOldFLqty.toFixed());
      console.log("farmer has fLQTY after ", farmerNewFLqty.toFixed());

      apr = (farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))*365;
      apy = ((farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))+1)**365;

      console.log("Overall APR:", apr*100, "%");
      console.log("Overall APY:", (apy-1)*100, "%");

      console.log("potpool totalShare: ", (new BigNumber(await potPool.totalSupply())).toFixed());
      console.log("fLQTY in potpool: ", (new BigNumber(await hodlVault.balanceOf(potPool.address))).toFixed());
      console.log("Farmer earned LUSD: ", farmerNewBalance - farmerOldBalance);
      console.log("Farmer got fLQTY from potpool: ", farmerNewFLqty.toFixed());
      console.log("earned!");

      // await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
