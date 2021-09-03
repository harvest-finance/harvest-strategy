// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

const Strategy = artifacts.require("UniverseStrategyMainnet_XYZ_USDC");
const IFeeRewardForwarder = artifacts.require("IFeeRewardForwarderV6");
const IStaking = artifacts.require("IStaking");

//This test was developed at blockNumber 13134890

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Universe XYZ/USDC", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  let underlyingWhale = "0x00924Dc49aB7a1C1b07a8166D05a09cC18E857eA";
  let xyz = "0x618679dF9EfCd19694BB1daa8D00718Eacfa2883";
  let usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let feeForwarderAddr = "0x153C544f72329c1ba521DDf5086cf2fA98C86676";
  let stakingAddr = "0x2d615795a8bdb804541C69798F13331126BA0c09";
  let sushiDex = "0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a";
  let bancorDex = "0x4bf11b89310db45ea1467e48e832606a6ec7b8735c470fff7cf328e182a7c37e";
  let stakingPool;
  let iFarm;

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
    underlying = await IERC20.at("0xBBBdB106A806173d1eEa1640961533fF3114d69A");
    iFarm = await IERC20.at(addresses.IFARM);
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance(){
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await web3.eth.sendTransaction({ from: etherGiver, to: underlyingWhale, value: 10e18});

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
      "strategyArtifactIsUpgradable": true,
      "underlying": underlying,
      "governance": governance,
      "liquidation": [{"sushi": [xyz, usdc]}],
    });

    feeForwarder = await IFeeRewardForwarder.at(feeForwarderAddr);
    let path = [xyz, usdc, addresses.FARM];
    let dexes = [sushiDex, bancorDex];
    await feeForwarder.configureLiquidation(path, dexes, { from: governance });

    // whale send underlying to farmers
    await setupBalance();

    stakingPool = await IStaking.at(stakingAddr);
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);
      let fTokenBalance = await vault.balanceOf(farmer1);

      let vaultERC20 = await IERC20.at(vault.address);
      await vaultERC20.approve(rewardPool.address, fTokenBalance, {from: farmer1});
      await rewardPool.stake(fTokenBalance, {from: farmer1});

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      //4 day steps to get the weekly rewards
      let blocksPerHour = 6530*2;
      let oldSharePrice;
      let newSharePrice;
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);

        //Epochs get automatically initialized on interactions with the staking contract
        //There is no compounding, so no interactions, so need manual initializaition in test
        epoch = await stakingPool.getCurrentEpoch();
        console.log("Epoch", new BigNumber(epoch).toFixed());
        init = await stakingPool.epochIsInitialized(underlying.address, epoch);
        if (!init) {
          console.log("Initializing Epoch", new BigNumber(epoch).toFixed());
          await stakingPool.manualEpochInit([underlying.address], epoch);
        }

        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log("old shareprice: ", oldSharePrice.toFixed());
        console.log("new shareprice: ", newSharePrice.toFixed());
        console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());
        console.log("iFarm in reward pool: ", (new BigNumber(await iFarm.balanceOf(rewardPool.address))).toFixed());

        apr = (newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))*365;
        apy = ((newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))+1)**365;

        // console.log("instant APR:", apr*100, "%");
        // console.log("instant APY:", (apy-1)*100, "%");

        await Utils.advanceNBlock(blocksPerHour);
      }
      await rewardPool.exit({from: farmer1});
      let farmerNewIFarm = new BigNumber(await iFarm.balanceOf(farmer1));
      console.log("farmerNewIFarm:    ", farmerNewIFarm.toFixed());

      await vault.withdraw(fTokenBalance, { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      // Utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      apr = (farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))*365;
      apy = ((farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))+1)**365;

      Utils.assertBNGt(farmerNewIFarm, 0);
      console.log("earned iFARM!");
      // console.log("Overall APR:", apr*100, "%");
      // console.log("Overall APY:", (apy-1)*100, "%");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
