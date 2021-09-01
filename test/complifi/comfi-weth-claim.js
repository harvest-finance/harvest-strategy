// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

//const Strategy = artifacts.require("");
const Strategy = artifacts.require("ComplifiStrategyClaimMainnet_COMFI_WETH");

//This test was developed at blockNumber 13138170

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Complifi: COMFI:WETH Vesting claim", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  let treasury = "0x0FB21490A878AA2Af08117C96F897095797bD91C";
  let reservoir = "0x22e1fe5bBB98a0eDA715B56a7bf04ed462BcA8d2";
  let comfi = "0x752Efadc0a7E05ad1BCCcDA22c141D01a75EF1e4";
  let comfiToken;

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
    underlying = await IERC20.at("0xe9C966bc01b4f14c0433800eFbffef4F81540A97");
    comfiToken = await IERC20.at(comfi);
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance(){
    let etherGiver = accounts[9];

    treasuryBalance = await comfiToken.balanceOf(treasury);
    await comfiToken.transfer(reservoir, treasuryBalance, { from: treasury });
  }

  before(async function() {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, treasury, msig]);

    await setupExternalContracts();
    [controller, vault, strategy] = await setupCoreProtocol({
      "existingVaultAddress": "0xB89777534acCcc9aE7cbA0e72163f9F214189263",
      "strategyArtifact": Strategy,
      "strategyArtifactIsUpgradable": true,
      "upgradeStrategy": true,
      "underlying": underlying,
      "governance": governance,
    });

    await strategy.finalizeUpgrade({from:governance});
    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Rewards should be claimed", async function() {
      // progress blocks to after "unlockBlock" at 13150000
      await Utils.advanceNBlock(12000);
      console.log("Strategy address:", strategy.address);

      let governanceBalanceBefore = new BigNumber(await comfiToken.balanceOf(governance));
      console.log("Governance COMFI balance before:", governanceBalanceBefore.toFixed());

      await strategy.claimRewards({from:governance});

      let governanceBalanceAfter = new BigNumber(await comfiToken.balanceOf(governance));
      console.log("Governance COMFI balance after:", governanceBalanceAfter.toFixed());

      Utils.assertBNGt(governanceBalanceAfter, governanceBalanceBefore);

      console.log("MSig address:", await strategy.multiSig());
    });
  });
});
