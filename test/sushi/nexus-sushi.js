// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

//const Strategy = artifacts.require("");
// const Strategy = artifacts.require("SushiStrategyMainnet_SUSHI_WETH");
const Strategy = artifacts.require("NexusSushiMasterChefLPStrategyMainnet");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Sushi: SUSHI:WETH", function() {
  let accounts;

  // external contracts
  let underlying;
  let usdc;

  // external setup
  let underlyingWhale = "0x88B521167CC35A22B51EA5caDD7DbCd4cc2Cbc57";

  const usdcWhale = "0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8"; // binance7

  // parties in the protocol
  let governance;
  let caplitalProvider;
  let farmer1;

  // numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let controller;
  let vault;
  let strategy;
  let nexusSushi;

  async function usdcBalance(address) {
    return BigNumber(await usdc.balanceOf(address));
  }

  async function ensureUsdBalance(address, amount) {
    if ((await usdcBalance(address)).lt(amount)) {
      await usdc.transfer(address, amount, { from: usdcWhale });
    }
  }

  async function supplyCapitalAsDeployer(deployer, nexus, amount) {
    await ensureUsdBalance(deployer, amount);
    await usdc.approve(nexus.address, amount);
    await nexus.depositAllCapital();
  }  

  async function setupExternalContracts() {
    underlying = await IERC20.at("0x795065dCc9f64b5614C407a6EFDC400DA6221FB0");
    usdc = await IERC20.at("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");
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

    farmer1 = accounts[1];
    caplitalProvider = accounts[0];

    // impersonate accounts
    await impersonates([governance, underlyingWhale, usdcWhale]);

    await setupExternalContracts();
    [controller, vault, strategy,, nexusSushi] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": Strategy,
      "strategyArtifactIsUpgradable": true,
      "underlying": underlying,
      "governance": governance
    });

    await supplyCapitalAsDeployer(caplitalProvider, nexusSushi, "100000000" + "000000");

    // nexusSushiFarmer = await nexusSushi.connect(farmer1);
    // await nexusSushiFarmer.deposit(farmer1, { value: ethers.utils.parseEther("1.0") });
    await nexusSushi.addLiquidityETH("2617551005", { value: "10000000000000" });

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let oldSharePrice;
      let newSharePrice;
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);
        let blocksPerHour = 2400;
        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log("old shareprice: ", oldSharePrice.toFixed());
        console.log("new shareprice: ", newSharePrice.toFixed());
        console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());

        await Utils.advanceNBlock(blocksPerHour);
      }
      const vaultBalance = new BigNumber(await vault.balanceOf(farmer1));
      console.log("vaultBalance: ", vaultBalance.toFixed());

      await vault.withdraw(vaultBalance.toFixed(), { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      Utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      console.log("earned!");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
