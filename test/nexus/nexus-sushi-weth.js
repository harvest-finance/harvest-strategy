const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const Strategy = artifacts.require("NexusLPSushiStrategy");
const NexusLP = artifacts.require("contracts/strategies/nexus/interface/INexusLPSushi.sol:INexusLPSushi");

const NEXUS_ADDRESS = "0x82DE6a95b5fe5CB38466686Ee09D4dC74C9b4A1a";

describe("LiquidityNexus SushiSwap: ETH", () => {
  // parties in the protocol
  const governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f"; // Harvest.finance deployer
  let nexusOwner;
  let farmer;

  // Core protocol contracts
  let controller;
  let vault;
  let strategy;

  let nexus;

  before(async function () {
    console.log("on block number", await web3.eth.getBlockNumber());

    nexus = await NexusLP.at(NEXUS_ADDRESS);
    nexusOwner = await nexus.owner();

    const accounts = await web3.eth.getAccounts();
    farmer = accounts[1];

    const usdcWhale = "0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8"; // binance7
    await impersonates([nexusOwner, governance, usdcWhale]);

    [controller, vault, strategy] = await setupCoreProtocol({
      existingVaultAddress: null,
      strategyArtifact: Strategy,
      strategyArtifactIsUpgradable: true,
      governance: governance,
      strategyArgs: [addresses.Storage, nexus.address, "vaultAddr"],
      underlying: { address: nexus.address },
    });

    nexus.setGovernance(strategy.address, { from: nexusOwner });

    await prepareNexusWithUSDC(usdcWhale);
  });

  async function prepareNexusWithUSDC(usdcWhale) {
    const amount = "10000000000000"; // $10M
    const USDC = await IERC20.at("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");
    await USDC.transfer(nexusOwner, amount, { from: usdcWhale });
    await USDC.approve(nexus.address, amount, { from: nexusOwner });
    await nexus.depositCapital(amount, { from: nexusOwner });
  }

  it("Farmer should earn", async () => {
    const depositETH = bn(web3.utils.toWei("1000", "ether"));

    const farmerStartBalanceETH = bn(await web3.eth.getBalance(farmer));

    Utils.assertBNGt(farmerStartBalanceETH, depositETH);
    Utils.assertBNGt(await nexus.availableSpaceToDepositETH(), depositETH); // how much ETH can be deposited to be paired with USDC

    console.log(`farmer enters LiquidityNexus with ${fmt(depositETH)} ETH`);
    await nexus.addLiquidityETH(farmer, deadline, { value: bn(depositETH), from: farmer }); // deposit accepts ETH or WETH

    const farmerStartBalanceLP = bn(await nexus.balanceOf(farmer));

    console.log("farmer deposits NexusLP to Vault");
    await nexus.approve(vault.address, farmerStartBalanceLP, { from: farmer });
    await vault.deposit(farmerStartBalanceLP, { from: farmer });

    // Using half days is to simulate how we doHardwork in the real world
    const doHardWorkWaitHours = 12;
    const avgBlockDurationSeconds = 13.2;
    const blocksPerHour = (60 * 60) / avgBlockDurationSeconds;
    const iterations = 10;

    let oldSharePrice;
    let newSharePrice;

    for (let i = 0; i < iterations; i++) {
      console.log("loop ", i);
      await Utils.advanceNBlock(blocksPerHour * doHardWorkWaitHours);

      oldSharePrice = bn(await vault.getPricePerFullShare());
      await controller.doHardWork(vault.address, { from: governance });
      newSharePrice = bn(await vault.getPricePerFullShare());

      Utils.assertBNEq(newSharePrice, oldSharePrice); // 1:1 ratio Nexus:Vault
      newSharePrice = newSharePrice.multipliedBy(await nexus.pricePerFullShare()).div(1e18); // NexusLP price increase

      console.log("old shareprice: ", fmt(oldSharePrice));
      console.log("new shareprice: ", fmt(newSharePrice));
      console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());
    }

    const vaultBalance = bn(await vault.balanceOf(farmer));
    console.log("vaultBalance: ", fmt(vaultBalance));
    Utils.assertBNEq(vaultBalance, farmerStartBalanceLP); // 1:1 ratio Nexus:Vault

    console.log("farmer withdraws from Vault");
    await vault.withdraw(vaultBalance, { from: farmer });
    const farmerEndBalanceLP = await nexus.balanceOf(farmer);
    Utils.assertBNEq(farmerEndBalanceLP, farmerStartBalanceLP); // 1:1 ratio Nexus:Vault

    console.log("farmer exits LiquidityNexus...");
    await nexus.removeAllLiquidityETH(farmer, deadline, { from: farmer });

    const farmerEndBalanceETH = bn(await web3.eth.getBalance(farmer));
    Utils.assertBNGt(farmerEndBalanceETH, farmerStartBalanceETH);
    console.log("start ETH balance", fmt(farmerStartBalanceETH));
    console.log("end ETH balance", fmt(farmerEndBalanceETH));
    console.log("principal", fmt(depositETH), "ETH");

    const profit = farmerEndBalanceETH.minus(farmerStartBalanceETH);
    console.log("profit", fmt(profit), "ETH");

    const testDuration = doHardWorkWaitHours * iterations;
    console.log("Test duration", testDuration, "hours");

    const profitPercent = profit / depositETH.toFixed();
    console.log("profit percent", profitPercent * 100, "%");

    const dailyYield = (profitPercent / testDuration) * 24;
    console.log("daily percent yield", dailyYield * 100, "%");

    const APR = dailyYield * 365;
    console.log("APR", APR * 100, "%");

    const APY = Math.pow(1 + dailyYield / 2, 365 * 2) - 1; // compounding twice a day
    console.log("APY", APY * 100, "%");

    console.log("earned!");

    await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
  });
});

function bn(n) {
  return new BigNumber(n);
}

function fmt(ether) {
  return web3.utils.fromWei(bn(ether).toFixed(), "ether");
}

const deadline = "100000000000";
