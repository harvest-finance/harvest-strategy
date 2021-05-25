// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

//const Strategy = artifacts.require("");
const Strategy = artifacts.require("LiftStrategyMainnet_lfBTC_LIFT");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Lift.Kitchen lfBTC/LIFT", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup blockNumber 12365175
  let underlyingWhale = "0x93006f9dc69Be8B9F1fEaAb318f3b4Bb3D32F2E8";
  let lift = "0xf9209d900f7ad1DC45376a2caA61c78f6dEA53B6";

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
    underlying = await IERC20.at("0x0e250c3FF736491712C5b11EcEe6d8dbFA41c78f");
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
    multiSig = "0xF49440C1F012d041802b25A73e5B0B9166a75c02";
    accounts = await web3.eth.getAccounts();

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

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);

      await strategy.setRewardClaimable(true, {from:governance});
      await controller.doHardWork(vault.address, { from: governance });

      let blocksPerHour = 2400;
      await Utils.advanceNBlock(blocksPerHour);

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let oldSharePrice;
      let newSharePrice;
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);
        oldStakedReward = new BigNumber(await strategy.stakedLift());
        await strategy.claimReward({ from: multiSig });
        newStakedReward = new BigNumber(await strategy.stakedLift());

        console.log("old staked reward: ", oldStakedReward.toFixed());
        console.log("new staked reward: ", newStakedReward.toFixed());
        console.log("diff: ", newStakedReward.toFixed() - oldStakedReward.toFixed());

        await Utils.advanceNBlock(blocksPerHour);
      }

      rewardToken = await IERC20.at(lift);

      msigBalance0 = new BigNumber(await rewardToken.balanceOf(multiSig)).toFixed();
      stakedLift0 = new BigNumber(await await strategy.stakedLift()).toFixed();
      console.log("Before claims: Staked Lift:", stakedLift0, "MSig Balance:", msigBalance0);
      console.log("");

      await strategy.withdrawRewardShareOldest({from: multiSig});
      msigBalance1 = new BigNumber(await rewardToken.balanceOf(multiSig)).toFixed();
      stakedLift1 = new BigNumber(await await strategy.stakedLift()).toFixed();
      console.log("Claim oldest: Staked Lift:", stakedLift1, "MSig Balance:", msigBalance1);
      console.log("Diff: Staked Lift:", stakedLift1-stakedLift0, "MSig Balance:", msigBalance1-msigBalance0);
      console.log("Efficiency:", (msigBalance1-msigBalance0)/(stakedLift0-stakedLift1)*100, "%");
      console.log("");

      await strategy.withdrawRewardShareNewest({from: multiSig});
      msigBalance2 = new BigNumber(await rewardToken.balanceOf(multiSig)).toFixed();
      stakedLift2 = new BigNumber(await await strategy.stakedLift()).toFixed();
      console.log("Claim newest: Staked Lift:", stakedLift2, "MSig Balance:", msigBalance2);
      console.log("Diff: Staked Lift:", stakedLift2-stakedLift1, "MSig Balance:", msigBalance2-msigBalance1);
      console.log("Efficiency:", (msigBalance2-msigBalance1)/(stakedLift1-stakedLift2)*100, "%");
      console.log("");

      console.log("Advance 24000 blocks...");
      console.log("");
      await Utils.advanceNBlock(blocksPerHour*100);

      await strategy.withdrawRewardShareOldest({from: multiSig});
      msigBalance3 = new BigNumber(await rewardToken.balanceOf(multiSig)).toFixed();
      stakedLift3 = new BigNumber(await await strategy.stakedLift()).toFixed();
      console.log("Claim oldest: Staked Lift:", stakedLift3, "MSig Balance:", msigBalance3);
      console.log("Diff: Staked Lift:", stakedLift3-stakedLift2, "MSig Balance:", msigBalance3-msigBalance2);
      console.log("Efficiency:", (msigBalance3-msigBalance2)/(stakedLift2-stakedLift3)*100, "%");
      console.log("");

      await strategy.withdrawRewardShareNewest({from: multiSig});
      msigBalance4 = new BigNumber(await rewardToken.balanceOf(multiSig)).toFixed();
      stakedLift4 = new BigNumber(await await strategy.stakedLift()).toFixed();
      console.log("Claim newest: Staked Lift:", stakedLift4, "MSig Balance:", msigBalance4);
      console.log("Diff: Staked Lift:", stakedLift4-stakedLift3, "MSig Balance:", msigBalance4-msigBalance3);
      console.log("Efficiency:", (msigBalance4-msigBalance3)/(stakedLift3-stakedLift4)*100, "%");
      console.log("");

      await strategy.withdrawRewardShareAll({from: multiSig});
      msigBalance5 = new BigNumber(await rewardToken.balanceOf(multiSig)).toFixed();
      stakedLift5 = new BigNumber(await await strategy.stakedLift()).toFixed();
      console.log("Claim all: Staked Lift:", stakedLift5, "MSig Balance:", msigBalance5);
      console.log("Diff: Staked Lift:", stakedLift5-stakedLift4, "MSig Balance:", msigBalance5-msigBalance4);
      console.log("Efficiency:", (msigBalance5-msigBalance4)/(stakedLift4-stakedLift5)*100, "%");
      console.log("");

      await vault.withdraw(new BigNumber(await vault.balanceOf(farmer1)).toFixed(), { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      console.log("farmerOldBalance: ", farmerOldBalance.toFixed());
      console.log("farmerNewBalance: ", farmerNewBalance.toFixed());
      Utils.assertBNEq(farmerNewBalance, farmerOldBalance);
      console.log("got the same amount back");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
