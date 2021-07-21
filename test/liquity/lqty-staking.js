const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");

const utils = require("../utilities/Utils.js");
const {
  depositVault,
  impersonates,
  setupCoreProtocol,
} = require("../utilities/hh-utils.js");

const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const LiquidatorRegistry = artifacts.require("ILiquidatorRegistry");
const Strategy = artifacts.require("LQTYStakingStrategyMainnet");

const BorrowerOperations = artifacts.require("IBorrowerOperations");
const TroveManager = artifacts.require("ITroveManager");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("LQTY Staking", function () {
  let accounts;

  // Parties in the protocol
  let governance;
  let farmer;
  let borrower;

  // Various numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let controller;
  let vault;
  let strategy;

  // Underlying LQTY token
  let underlying;

  // Liquity contracts
  let borrowerOperations;
  let troveManager;

  // External setup - use block 12779422
  let underlyingWhale = "0xF6323aD07c30D696D3e572cb4648814F1188372D";
  let redeemer = "0x00000000a4569cda123E73F94e35f9a625650Be6";

  const setupExternalContracts = async () => {
    underlying = await IERC20.at("0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D");

    borrowerOperations = await BorrowerOperations.at(
      "0x24179cd81c9e782a4096035f7ec97fb8b783e007"
    );
    troveManager = await TroveManager.at(
      "0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2"
    );
  };

  const setupBalance = async () => {
    farmerBalance = await underlying.balanceOf(underlyingWhale);

    // Transfer underlying from whale to farmer
    await underlying.transfer(farmer, farmerBalance, {
      from: underlyingWhale,
    });
  };

  const setupULPath = async () => {
    // Set up a path from WETH to LQTY via UniswapV3 on UL
    const registry = await LiquidatorRegistry.at(
      "0x7882172921e99d590e097cd600554339fbdbc480"
    );

    await registry.setPath(
      // Via UniswapV3
      "0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f",
      // From WETH
      "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      // To LQTY
      "0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D",
      // Path
      [
        "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        "0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D",
      ],
      { from: governance }
    );
  };

  const triggerETHRewards = async () => {
    // Redeem collateral for triggering ETH rewards
    // Taken from:
    // https://etherscan.io/tx/0x412d43815d9b6493013bdb328b14ebc009cdb47b2b967cd19c73652b1dd83bd5
    await troveManager.redeemCollateral(
      "236105850000000000000000",
      "0xEbC584Cc13ca8605cCA374cf1903d04cC8038c22",
      "0x6458f999E595D3bDA5692db9df011CCD4ab13a96",
      "0xD06790e35B6E722F30082eA2C23417DB3B2244DC",
      "73661793753001982",
      "70",
      "6156037306201832",
      { from: redeemer }
    );
  };

  const triggerLUSDRewards = async () => {
    // Open trove for triggering LUSD rewards
    // Taken from:
    // https://etherscan.io/tx/0x8533fac9e75a9ccd48634ca91ec41ddb9b27079f29114329fdd8c47ada7fd021
    await borrowerOperations.openTrove(
      "10000019807318437",
      "40000000000000000000000",
      "0xb2969D3429e99E4846E5bE4Df47d74bA87069E0D",
      "0xDb150346155675dd0C93eFd960d5985244a34820",
      { from: borrower, value: "97500000000000000000" }
    );
  };

  before(async function () {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    farmer = accounts[1];
    borrower = accounts[2];

    // Impersonate accounts
    await impersonates([governance, underlyingWhale, redeemer]);

    await setupExternalContracts();

    const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    const farm = "0xa0246c9032bC3A600820415aE600c6388619A14D";

    [controller, vault, strategy] = await setupCoreProtocol({
      existingVaultAddress: null,
      strategyArtifact: Strategy,
      strategyArtifactIsUpgradable: true,
      underlying,
      governance,
      liquidation: [{ uni: [weth, farm] }],
    });

    // Send underlying from whale to farmers
    await setupBalance();

    await setupULPath();
  });

  describe("Happy path", function () {
    it("Farmer should earn money", async function () {
      const farmerOldBalance = new BigNumber(
        await underlying.balanceOf(farmer)
      );
      await depositVault(farmer, underlying, vault, farmerBalance);

      let oldSharePrice;
      let newSharePrice;

      for (let i = 0; i < 3; i++) {
        console.log(`loop ${i}`);

        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log(`old shareprice: ${oldSharePrice.toFixed()}`);
        console.log(`new shareprice: ${newSharePrice.toFixed()}`);
        console.log(
          `growth: ${newSharePrice.toFixed() / oldSharePrice.toFixed()}`
        );

        if (i == 0) {
          await triggerETHRewards();
        } else if (i == 1) {
          await triggerLUSDRewards();
        }
      }

      await vault.withdraw(farmerBalance, { from: farmer });
      const farmerNewBalance = new BigNumber(
        await underlying.balanceOf(farmer)
      );
      utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      console.log(
        `Earned ${farmerNewBalance.minus(farmerOldBalance).toFixed()}`
      );

      // Just making sure we can withdraw all
      await strategy.withdrawAllToVault({ from: governance });
    });
  });
});
