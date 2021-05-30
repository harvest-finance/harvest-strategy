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

const DodoStrategyMainnet_USDT_USDC_USDT = artifacts.require(
  "DodoStrategyMainnet_USDT_USDC_USDT"
);

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet USDT/USDC USDT LP", function () {
  let accounts;

  // Parties in the protocol
  let governance;
  let farmer;

  // Various numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let controller;
  let vault;
  let strategy;

  // Underlying USDT LP token for the DODOEX V1 USDT/USDC pool
  let underlying;

  // External setup - use block 12535549
  let underlyingWhale = "0xFA54DAB921C65050ccb7eD5AFFFdD2178CedEb91";

  const setupExternalContracts = async () => {
    underlying = await IERC20.at("0x50b11247bF14eE5116C855CDe9963fa376FceC86");
  };

  const setupBalance = async () => {
    farmerBalance = await underlying.balanceOf(underlyingWhale);

    // Transfer underlying from whale to farmer
    await underlying.transfer(farmer, farmerBalance, {
      from: underlyingWhale,
    });
  };

  before(async function () {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    farmer = accounts[1];

    // Impersonate accounts
    await impersonates([governance, underlyingWhale]);

    await setupExternalContracts();

    const dodo = "0x43Dfc4159D86F3A37A5A4B3D4580b888ad7d4DDd";
    const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    const farm = "0xa0246c9032bC3A600820415aE600c6388619A14D";

    [controller, vault, strategy] = await setupCoreProtocol({
      existingVaultAddress: null,
      strategyArtifact: DodoStrategyMainnet_USDT_USDC_USDT,
      underlying: underlying,
      governance: governance,
      liquidation: [{ uni: [dodo, weth, farm] }],
    });

    // Send underlying from whale to farmers
    await setupBalance();
  });

  describe("Happy path", function () {
    it("Farmer should earn money", async function () {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer));
      await depositVault(farmer, underlying, vault, farmerBalance);

      // Using half days is to simulate how we `doHardWork` in the real world
      let hours = 10;
      let blocksPerHour = 2400;

      let oldSharePrice;
      let newSharePrice;

      for (let i = 0; i < hours; i++) {
        console.log(`loop ${i}`);

        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log(`old shareprice: ${oldSharePrice.toFixed()}`);
        console.log(`new shareprice: ${newSharePrice.toFixed()}`);
        console.log(
          `growth: ${newSharePrice.toFixed() / oldSharePrice.toFixed()}`
        );

        await utils.advanceNBlock(blocksPerHour);
      }

      await vault.withdraw(farmerBalance, { from: farmer });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer));
      utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      console.log(
        `Earned ${farmerNewBalance.minus(farmerOldBalance).toFixed()}`
      );

      // Just making sure we can withdraw all
      await strategy.withdrawAllToVault({ from: governance });
    });
  });
});
