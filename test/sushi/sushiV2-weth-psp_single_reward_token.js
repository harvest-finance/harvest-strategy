// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

const Strategy = artifacts.require("SushiV2StrategyULMainnet_WETH_PSP_SINGLE_REWARD_TOKEN");
const IFeeRewardForwarder = artifacts.require("IFeeRewardForwarderV6");

//This test was developed at blockNumber 13885848

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Sushiswap WETH-PSP single reward token", function () {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  let underlyingWhale = "0xfceaec3f6b35272041331cfbc59dad069870509b";
  let psp = "0xcAfE001067cDEF266AfB7Eb5A286dCFD277f3dE5";
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let feeForwarderAddr = "0x153C544f72329c1ba521DDf5086cf2fA98C86676";

  let sushi = "0x6B3595068778DD592e39A122f4f5a5cF09C90fE2";

  let sushiDexBytes32 = "0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a";
  let bancorDexBytes32 = "0x4bf11b89310db45ea1467e48e832606a6ec7b8735c470fff7cf328e182a7c37e";

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
    underlying = await IERC20.at("0x458ae80894A0924Ac763C034977e330c565F1687");
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance() {
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await web3.eth.sendTransaction({ from: etherGiver, to: underlyingWhale, value: 10e18 });
    await web3.eth.sendTransaction({ from: etherGiver, to: governance, value: 10e18 });

    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, { from: underlyingWhale });
  }

  before(async function () {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale]);

    await setupExternalContracts();
    // whale send underlying to farmers
    await setupBalance();

    [controller, vault, strategy] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": Strategy,
      "strategyArtifactIsUpgradable": true,
      "underlying": underlying,
      "governance": governance,
      //{ "sushi": [sushi, weth] } does already exist, but added for completness
      "liquidation": [{ "sushi": [sushi, weth] }, { "sushi": [weth, psp] }],
    });

    let feeForwarder = await IFeeRewardForwarder.at(feeForwarderAddr);
    let path = [sushi, weth, addresses.FARM];
    let dexes = [sushiDexBytes32, bancorDexBytes32];
    await feeForwarder.configureLiquidation(path, dexes, { from: governance });
  });

  describe("Happy path", function () {
    it("Farmer should earn money", async function () {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);
      let fTokenBalance = await vault.balanceOf(farmer1);

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let blocksPerHour = 2400;
      let oldSharePrice;
      let newSharePrice;
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);
        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log("old shareprice: ", oldSharePrice.toFixed());
        console.log("new shareprice: ", newSharePrice.toFixed());
        console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());

        apr = (newSharePrice.toFixed() / oldSharePrice.toFixed() - 1) * (24 / (blocksPerHour / 272)) * 365;
        apy = ((newSharePrice.toFixed() / oldSharePrice.toFixed() - 1) * (24 / (blocksPerHour / 272)) + 1) ** 365;

        console.log("instant APR:", apr * 100, "%");
        console.log("instant APY:", (apy - 1) * 100, "%");

        await Utils.advanceNBlock(blocksPerHour);
      }
      await vault.withdraw(fTokenBalance, { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      Utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      apr = (farmerNewBalance.toFixed() / farmerOldBalance.toFixed() - 1) * (24 / (blocksPerHour * hours / 272)) * 365;
      apy = ((farmerNewBalance.toFixed() / farmerOldBalance.toFixed() - 1) * (24 / (blocksPerHour * hours / 272)) + 1) ** 365;

      console.log("earned!");
      console.log("Overall APR:", apr * 100, "%");
      console.log("Overall APY:", (apy - 1) * 100, "%");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });


  describe("Basic strategy functionality checks", function () {
    it("Deposit to vault", async function () {
      // deposit to vault such that we have something to work with
      await depositVault(farmer1, underlying, vault, farmerBalance);

      // check vault has at least farmerBalance (there could be some dust etc., so no exact check)
      let vaultUnderlying = new BigNumber(await vault.underlyingBalanceInVault());
      Utils.assertBNGte(vaultUnderlying, farmerBalance)
    });

    it("withdrawAllToVault()", async function () {
      let vaultUnderlying = new BigNumber(await vault.underlyingBalanceInVault());
      // doHardwork invests all underlying from the vault
      await controller.doHardWork(vault.address, { from: governance });
      let investedUnderlyingBalance = new BigNumber(await strategy.investedUnderlyingBalance());

      // strategy invested amount must be greater or equal than the initial vault underlying amount
      Utils.assertBNGte(investedUnderlyingBalance, vaultUnderlying)

      // move all invested underlying back to the vault
      await strategy.withdrawAllToVault({ from: governance });

      // strategy has no underlying left
      let investedUnderlyingBalanceNew = new BigNumber(await strategy.investedUnderlyingBalance());
      assert.equal(investedUnderlyingBalanceNew.eq(BigNumber(0)), true);

      // vault has all of the underlying from the strategy
      let vaultUnderlyingNew = new BigNumber(await vault.underlyingBalanceInVault());
      Utils.assertBNGte(vaultUnderlyingNew, investedUnderlyingBalance)
    });

    it("withdrawToVault(uint256 _amount)", async function () {
      let vaultUnderlying = new BigNumber(await vault.underlyingBalanceInVault());
      // doHardwork invests all underlying from the vault
      await controller.doHardWork(vault.address, { from: governance });
      let investedUnderlyingBalance = new BigNumber(await strategy.investedUnderlyingBalance());

      // strategy invested amount must be greater or equal than the initial vault underlying amount
      Utils.assertBNGte(investedUnderlyingBalance, vaultUnderlying)

      let amount = 1;
      // move amount of underlying to vault
      await strategy.withdrawToVault(amount, { from: governance });

      // vault has exactly amount of underlying
      let vaultUnderlyingNew = new BigNumber(await vault.underlyingBalanceInVault());
      assert.equal(new BigNumber(amount).eq(vaultUnderlyingNew), true);
    });

    it("emergencyExit()", async function () {
      let vaultUnderlying = new BigNumber(await vault.underlyingBalanceInVault());
      // doHardwork invests all underlying from the vault
      await controller.doHardWork(vault.address, { from: governance });
      let investedUnderlyingBalance = new BigNumber(await strategy.investedUnderlyingBalance());

      // emergency exit of the strategy, moves all the underlying from the rewardPool to the strategy
      await strategy.emergencyExit({ from: governance });
      let isPausedInvesting = await strategy.pausedInvesting();

      // flag _PAUSED_INVESTING_SLOT is set to true
      assert.equal(isPausedInvesting, true);

      // strategy has all the underlying
      let investedUnderlyingBalanceNew = new BigNumber(await strategy.investedUnderlyingBalance());
      let strategyBalance = new BigNumber(await underlying.balanceOf(strategy.address));
      assert.equal(strategyBalance.eq(investedUnderlyingBalanceNew), true);

      // set flag _PAUSED_INVESTING_SLOT to false
      await strategy.continueInvesting({ from: governance });
      isPausedInvesting = await strategy.pausedInvesting();
      assert.equal(isPausedInvesting, false);

    });

    it("unsalvagableTokens(address _token)", async function () {
      // underlying is unsalvageable
      let isUnderlyingUnsalvagable = await strategy.unsalvagableTokens(underlying.address);
      assert.equal(isUnderlyingUnsalvagable, true);

      // rewardToken is unsalvageable
      let isRewardTokenUnsalvagable = await strategy.unsalvagableTokens(await strategy.rewardToken());
      assert.equal(isRewardTokenUnsalvagable, true);
    });

    it("Remove all deposited LP tokens", async function () {
      // remove all deposited LP tokens
      let fTokenBalance = await vault.balanceOf(farmer1);
      await vault.withdraw(fTokenBalance, { from: farmer1 });

      //check that there is nothing left in the strategy or vault
      let strategyBalance = new BigNumber(await underlying.balanceOf(strategy.address));
      assert.equal(strategyBalance.eq(BigNumber(0)), true);

      let vaultBalance = new BigNumber(await underlying.balanceOf(vault.address));
      assert.equal(vaultBalance.eq(BigNumber(0)), true);

      let totalUnderlyingVaultAndStrategy = new BigNumber(await vault.underlyingBalanceWithInvestment());
      assert.equal(totalUnderlyingVaultAndStrategy.eq(BigNumber(0)), true);
    });
  });
});