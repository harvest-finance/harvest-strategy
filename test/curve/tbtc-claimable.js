// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

//const Strategy = artifacts.require("");
const Strategy = artifacts.require("CRVStrategyTBTCMixedMainnet");

//Test developed at blockNumber 11997700

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Curve TBTC (claimable)", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  // block number: 12450065
  let underlyingWhale = "0x32d2d8a08e29668492724b83d81c750123b6b905";

  // parties in the protocol
  let governance;
  let farmer1;

  // numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let controller;
  let vault;
  let strategy;
  let multiSig;

  async function setupExternalContracts() {
    underlying = await IERC20.at("0x64eda51d3Ad40D56b9dFc5554E06F94e1Dd786Fd");
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
    multiSig = "0xF49440C1F012d041802b25A73e5B0B9166a75c02";

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale, multiSig]);

    await setupExternalContracts();
    [controller, vault, strategy] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": Strategy,
      "underlying": underlying,
      "governance": governance,
    });

    await strategy.setSellFloor(0, {from:governance});

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      await strategy.setSell(false, {from: governance});
      await strategy.setRewardClaimable(true, {from: governance});
      await controller.doHardWork(vault.address, { from: governance });

      let reward = await IERC20.at("0xD533a949740bb3306d119CC777fa900bA034cd52");
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);
        let blocksPerHour = 2400;
        let rewardBalanceBefore = new BigNumber(await reward.balanceOf(multiSig));
        await strategy.claimReward({from: multiSig});
        let rewardBalanceAfter = new BigNumber(await reward.balanceOf(multiSig));

        console.log("rewardBalanceBefore: ", rewardBalanceBefore.toFixed());
        console.log("rewardBalanceAfter: ", rewardBalanceAfter.toFixed());
        console.log("diff: ", (rewardBalanceAfter.minus(rewardBalanceBefore)).toFixed());

        await Utils.advanceNBlock(blocksPerHour);
      }
      await vault.withdraw(farmerBalance, { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      Utils.assertBNGte(farmerNewBalance, farmerOldBalance);

      console.log("earned!");

    });
  });
});
