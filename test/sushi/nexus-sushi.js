// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

const Strategy = artifacts.require("NexusSushiMasterChefLPStrategyMainnet");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Nexus: SUSHI:ETH", function() {
  let accounts;

  // external contracts
  let usdc;

  // external setup
  let usdcWhale = "0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8"; // binance7

  // parties in the protocol
  let governance;
  let farmer;
  
  // Core protocol contracts
  let controller;
  let vault;
  let strategy;
  let nexusSushi;

  let ethToDeposit = ethers.utils.parseEther("2000.0");

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
    usdc = await IERC20.at("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");
    console.log("Fetching Underlying at: ", usdc.address);
  }

  before(async function() {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    farmer = accounts[0];
    
    // impersonate accounts
    await impersonates([governance, usdcWhale]);

    await setupExternalContracts();
    [controller, vault, strategy,, nexusSushi] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": Strategy,
      "strategyArtifactIsUpgradable": true,
      "governance": governance,
      "strategyArgs": [addresses.Storage, "vaultAddr", "nexusSushi", addresses.orbsInsurance, 0]
    });

    await supplyCapitalAsDeployer(farmer, nexusSushi, "100000000" + "000000");
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldEthBalance = await web3.eth.getBalance(farmer);

      await nexusSushi.addLiquidityETH("2617551005", { value: ethToDeposit });

      let farmerOldLPBalance = await nexusSushi.balanceOf(farmer);
      await nexusSushi.approve(vault.address, farmerOldLPBalance);
      await vault.deposit(farmerOldLPBalance);

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

        // TODO
        // console.log("old shareprice: ", oldSharePrice.toFixed());
        // console.log("new shareprice: ", newSharePrice.toFixed());
        // console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());

        await Utils.advanceNBlock(blocksPerHour);
      }
      const vaultBalance = new BigNumber(await vault.balanceOf(farmer));
      console.log("vaultBalance: ", vaultBalance.toFixed());

      await vault.withdraw(vaultBalance.toFixed(), { from: farmer });
      let farmerNewLPBalance = await nexusSushi.balanceOf(farmer);

      await nexusSushi.removeLiquidityETH(farmerNewLPBalance, "2617551005");

      let farmerNewEthBalance = await web3.eth.getBalance(farmer);

      console.log('a.toString()!!!!');
      console.log(farmerNewEthBalance.toString());
      console.log(farmerOldEthBalance.toString());

      Utils.assertBNGt(farmerNewEthBalance, farmerOldEthBalance);

      console.log("earned!");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
