// Utilities
const Utils = require("../../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../../utilities/hh-utils.js");

const addresses = require("../../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const IBooster = artifacts.require("IBooster");
const IFeeForwarder = artifacts.require("IFeeRewardForwarderV6");

const HodlStrategy = artifacts.require("ConvexStrategyCVXMainnet");
const Strategy = artifacts.require("ConvexStrategyCompoundHodlMainnet");

//This test was developed at blockNumber 12555215

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex Compound HODL", function() {
  let accounts;

  // external contracts
  let underlying;
  let cvxToken;
  let priceFeed;

  // external setup
  let underlyingWhale = "0x3d8D742EE7fbc497ae671528a19a1489BA204482";
  let booster;
  let cvxcrv = "0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7";
  let crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let unidex = "0xde2d1a51640f78257713031680d1f306297d957426e912ab21317b9cc9495a41";
  let sushidex = "0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a";
  let cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";


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
    underlying = await IERC20.at("0x845838DF265Dcd2c412A1Dc9e959c7d08537f8a2");
    console.log("Fetching Underlying at: ", underlying.address);
    cvxToken = await IERC20.at(cvx);
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
    [controller, hodlVault, hodlStrategy] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": HodlStrategy,
      "strategyArtifactIsUpgradable": true,
      "underlying": cvxToken,
      "governance": governance,
      "liquidation": [{"sushi": [cvxcrv, crv, weth]}],
    });

    await hodlStrategy.setSellFloor(0, {from:governance});
    feeForwarder = await IFeeForwarder.at(addresses.FeeForwarderV6);
    await feeForwarder.configureLiquidation(
      [cvxcrv, weth, addresses.FARM],
      [sushidex, unidex],
      {from: governance}
    );

    await setupExternalContracts();
    [controller, vault, strategy, potPool] = await setupCoreProtocol({
      "existingVaultAddress": "0x998cEb152A42a3EaC1f555B1E911642BeBf00faD",
      "strategyArtifact": Strategy,
      "strategyArtifactIsUpgradable": true,
      "announceStrategy": true,
      "underlying": underlying,
      "governance": governance,
      "rewardPool" : true,
      "rewardPoolConfig": {
        type: 'PotPool',
        rewardTokens: [
          addresses.IFARM,
          hodlVault.address
        ]}
    });

    await strategy._setPotPool(potPool.address, {from: governance});
    await strategy._setHodlVault(hodlVault.address, {from: governance});
    await potPool.setRewardDistribution([strategy.address], true, {from: governance});
    await strategy.setSellFloor(0, {from:governance});

    booster = await IBooster.at("0xF403C135812408BFbE8713b5A23a04b3D48AAE31");

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      let farmerOldfCVX = new BigNumber(await hodlVault.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);
      let fTokenBalance = await vault.balanceOf(farmer1);

      let erc20Vault = await IERC20.at(vault.address);

      await erc20Vault.approve(potPool.address, fTokenBalance, {from: farmer1});
      await potPool.stake(fTokenBalance, {from: farmer1});

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let blocksPerHour = 4800;
      let oldSharePrice;
      let newSharePrice;
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);

        await booster.earmarkRewards(await strategy.poolId());

        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        oldHodlSharePrice = new BigNumber(await hodlVault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        await controller.doHardWork(hodlVault.address, {from: governance});
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());
        newHodlSharePrice = new BigNumber(await hodlVault.getPricePerFullShare());

        console.log("old shareprice: ", oldSharePrice.toFixed());
        console.log("new shareprice: ", newSharePrice.toFixed());
        console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());

        console.log("fCVX in potpool: ", (new BigNumber(await hodlVault.balanceOf(potPool.address))).toFixed() );

        apr = (newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))*365;
        apy = ((newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))+1)**365;

        console.log("instant APR:", apr*100, "%");
        console.log("instant APY:", (apy-1)*100, "%");

        await Utils.advanceNBlock(blocksPerHour);
      }

      // withdrawAll to make sure no doHardwork is called when we do withdraw later.
      await vault.withdrawAll({ from: governance });

      // wait until all reward can be claimed by the farmer
      await Utils.waitTime(86400 * 30 * 1000);
      console.log("vaultBalance: ", new BigNumber(fTokenBalance).toFixed());
      await potPool.exit({from: farmer1});
      await vault.withdraw(fTokenBalance, { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      let farmerNewfCVX = new BigNumber(await hodlVault.balanceOf(farmer1));
      Utils.assertBNGt(farmerNewBalance, farmerOldBalance);
      Utils.assertBNGt(farmerNewfCVX, farmerOldfCVX);

      console.log("potpool totalShare: ", (new BigNumber(await potPool.totalSupply())).toFixed());
      console.log("fCVX in potpool: ", (new BigNumber(await hodlVault.balanceOf(potPool.address))).toFixed() );
      console.log("Farmer got fSushi from potpool: ", farmerNewfCVX.toFixed());

      apr = (farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))*365;
      apy = ((farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))+1)**365;

      console.log("earned!");
      console.log("Overall APR:", apr*100, "%");
      console.log("Overall APY:", (apy-1)*100, "%");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
