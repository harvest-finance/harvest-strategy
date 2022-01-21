// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");
const { time } = require("@openzeppelin/test-helpers");

const addresses = require("../test-config.js");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

const Strategy = artifacts.require("LooksRareStakingStrategyMainnet_LOOKS");
const IFeeRewardForwarder = artifacts.require("IFeeRewardForwarderV6");
const IOperatorControllerForRewards = artifacts.require("IOperatorControllerForRewards");
const IFeeSharingSetter = artifacts.require("IFeeSharingSetter");

// This test was developed at blockNumber 14033537
// for this test we simulate repleneshing rewards so the block number depends on
// a good timing of when the repleneshing last happened to get realistic results

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet LooksRare Staking LOOKS", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  let underlyingWhale = "0x52329Bf439AF2381eC3a22CF702d9f82562F820f";
  let looks = "0xf4d2888d29D722226FafA5d9B24F9164c092421E";
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let feeForwarderAddr = "0x153C544f72329c1ba521DDf5086cf2fA98C86676";

  // used to update rewards simulated for the distribution from LOOKS smart contracts
  let operatorControllerForRewards;
  let operatorControllerForRewardsAddress = "0xb6c40EB22dBdC87FdDf4B70d460934a44b7EbE01";
  let rewardsControllerOwner = "0xAa27e4FCCcBF24B1f745cf5b2ECee018E91a5e5e";
  let feeSharingSetter;
  let feeSharingSetterAddr = "0x5924A28caAF1cc016617874a2f0C3710d881f3c1";

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
  let feeForwarder;

  async function setupExternalContracts() {
    underlying = await IERC20.at("0xf4d2888d29D722226FafA5d9B24F9164c092421E");
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance(){
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await web3.eth.sendTransaction({ from: etherGiver, to: underlyingWhale, value: 10e18});
    await web3.eth.sendTransaction({ from: etherGiver, to: governance, value: 10e18});
    await web3.eth.sendTransaction({ from: etherGiver, to: rewardsControllerOwner, value: 10e18});

    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, { from: underlyingWhale });
  }

  before(async function() {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale, rewardsControllerOwner]);

    await setupExternalContracts();
    // whale send underlying to farmers
    await setupBalance();

    [controller, vault, strategy] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": Strategy,
      "strategyArtifactIsUpgradable": true,
      "underlying": underlying,
      "governance": governance,
      "liquidation": [{"uni": [weth, looks]}],
    });

    operatorControllerForRewards = await IOperatorControllerForRewards.at(operatorControllerForRewardsAddress);
    feeSharingSetter = await IFeeSharingSetter.at(feeSharingSetterAddr);

    let feeForwarder = await IFeeRewardForwarder.at(feeForwarderAddr);
    let path = [weth, addresses.FARM];
    let dexes = [bancorDex];
    await feeForwarder.configureLiquidation(path, dexes, {from: governance});
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);
      let fTokenBalance = await vault.balanceOf(farmer1);

      let wethWhale = "0xE78388b4CE79068e89Bf8aA7f218eF6b9AB0e9d0";
      await impersonates([governance, underlyingWhale, rewardsControllerOwner, wethWhale]);
      let wethERC20 = await IERC20.at(weth);
      let initalFeeSharingSetterBalance = await wethERC20.balanceOf(feeSharingSetterAddr);
      console.log("initalFeeSharingSetterBalance (used throughout test as rewards base)")
      console.log(new BigNumber(initalFeeSharingSetterBalance).toFixed());

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let blocksPerHour = 2400;
      let oldSharePrice;
      let newSharePrice;
      for (let i = 0; i < hours; i++) {
        console.log("\n\n ----------------- loop ", i, " -----------------------");

        // check if we have to simulate updating rewards at LOOKS fee sharing system
        const rewardDurationInBlocks = await feeSharingSetter.rewardDurationInBlocks();
        const lastRewardDistributionBlock = await feeSharingSetter.lastRewardDistributionBlock();
        const block = await time.latestBlock();

        if(block > new BigNumber(rewardDurationInBlocks).plus(lastRewardDistributionBlock)){
          console.log("\nSimulating updating rewards");
          const currentFeeSharingSetterBalance = await wethERC20.balanceOf(feeSharingSetterAddr);
          console.log("currentFeeSharingSetterBalance:", new BigNumber(currentFeeSharingSetterBalance).toFixed())
          const balanceDifference = new BigNumber(initalFeeSharingSetterBalance).minus(currentFeeSharingSetterBalance);
          if(balanceDifference > 0){
            // LOOKS feeSharingSystem calculates rewards based on balance of WETH in the contract
            // we simulate the contract having the same balance at the beginning of the test
            console.log("repleneshing feeSetterBalance with WETH: ", new BigNumber(balanceDifference).toFixed());
            await wethERC20.transfer(feeSharingSetterAddr, balanceDifference, { from: wethWhale });
          }
          await operatorControllerForRewards.releaseTokensAndUpdateRewards({from: rewardsControllerOwner});
        }

        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log("\nold shareprice: ", oldSharePrice.toFixed());
        console.log("new shareprice: ", newSharePrice.toFixed());
        console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());

        apr = (newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))*365;
        apy = ((newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))+1)**365;

        console.log("instant APR:", apr*100, "%");
        console.log("instant APY:", (apy-1)*100, "%");
        console.log(`Instant APR / APY might be a bit off in this test depending on the loop, make sure the Overall APR / APY is in line.`);

        await Utils.advanceNBlock(blocksPerHour);
      }
      // withdraw only part to check if the withdrawToVault method works
      const halfBalance = new BigNumber(fTokenBalance).div(2);
      await vault.withdraw(halfBalance, { from: farmer1 });
      let restfTokenBalance = await vault.balanceOf(farmer1);
      // make sure rest of the balance matches
      Utils.assertBNGte(halfBalance, restfTokenBalance);

      await vault.withdraw(restfTokenBalance, { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      Utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      apr = (farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))*365;
      apy = ((farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))+1)**365;

      console.log("\n\n ---------- earned! -----------");
      console.log("Overall APR:", apr*100, "%");
      console.log("Overall APY:", (apy-1)*100, "%");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
