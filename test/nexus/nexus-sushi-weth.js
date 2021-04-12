const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const Strategy = artifacts.require("NexusLPSushiStrategy");

const deadline = "100000000000";

describe("LiquidityNexus: SUSHI:WETH", () => {
  let USDC;

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
    const accounts = await web3.eth.getAccounts();
    nexusOwner = accounts[0];
    farmer = accounts[1];
    const usdcWhale = "0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8"; // binance7
    await impersonates([governance, usdcWhale]);

    USDC = await IERC20.at("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");

    nexus = await TEMP_DELETE_BEFORE_DEPLOYMENT(nexusOwner);

    [controller, vault, strategy] = await setupCoreProtocol({
      existingVaultAddress: null,
      strategyArtifact: Strategy,
      strategyArtifactIsUpgradable: true,
      governance: governance,
      strategyArgs: [addresses.Storage, nexus.options.address, "vaultAddr"],
      underlying: { address: nexus.options.address },
    });

    nexus.methods.setGovernance(strategy.address).send({ from: nexusOwner });

    await prepareNexusWithUSDC(usdcWhale);
  });

  async function prepareNexusWithUSDC(usdcWhale) {
    const amount = web3.utils.toWei(10_000_000 + "", "lovelace");
    await USDC.transfer(nexusOwner, amount, { from: usdcWhale });
    await USDC.approve(nexus.options.address, amount, { from: nexusOwner });
    await nexus.methods.depositAllCapital().send({ from: nexusOwner });
  }

  it("Farmer should earn", async () => {
    const depositETH = web3.utils.toWei("500", "ether");

    const farmerStartBalanceETH = bn(await web3.eth.getBalance(farmer));

    Utils.assertBNGt(farmerStartBalanceETH, depositETH);
    Utils.assertBNGt(await nexus.methods.availableSpaceToDepositETH().call(), depositETH);

    console.log(`farmer enters LiquidityNexus with ${fmt(depositETH)} ETH`);
    await nexus.methods.addLiquidityETH(farmer, deadline).send({ value: bn(depositETH), from: farmer });

    const farmerStartBalanceLP = bn(await nexus.methods.balanceOf(farmer).call());

    console.log("farmer deposits NexusLP to Vault");
    await nexus.methods.approve(vault.address, farmerStartBalanceLP).send({ from: farmer });
    await vault.deposit(farmerStartBalanceLP, { from: farmer });

    // Using half days is to simulate how we doHardwork in the real world
    const doHardWorkWaitHours = 12;
    const avgBlockDuration = 13.03;
    const blocksPerHour = (60 * 60) / avgBlockDuration;
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
      newSharePrice = newSharePrice.multipliedBy(await nexus.methods.pricePerFullShare().call()).div(1e18); // price increases on LiquidityNexus side

      console.log("old shareprice: ", oldSharePrice.toFixed());
      console.log("new shareprice: ", newSharePrice.toFixed());
      console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());
    }

    const vaultBalance = bn(await vault.balanceOf(farmer));
    console.log("vaultBalance: ", vaultBalance.toFixed());
    Utils.assertBNEq(vaultBalance, farmerStartBalanceLP); // 1:1 ratio Nexus:Vault

    console.log("farmer withdraws from Vault");
    await vault.withdraw(vaultBalance.toFixed(), { from: farmer });
    const farmerEndBalanceLP = await nexus.methods.balanceOf(farmer).call();
    Utils.assertBNEq(farmerEndBalanceLP, farmerStartBalanceLP); // 1:1 ratio Nexus:Vault

    console.log("farmer exits LiquidityNexus...");
    await nexus.methods.removeAllLiquidityETH(farmer, deadline).send({ from: farmer });

    const farmerEndBalanceETH = await web3.eth.getBalance(farmer);
    Utils.assertBNGt(farmerEndBalanceETH, farmerStartBalanceETH);
    console.log("start ETH balance", fmt(farmerStartBalanceETH));
    console.log("end ETH balance", fmt(farmerEndBalanceETH));
    console.log("principal", fmt(depositETH), "ETH");

    const profit = bn(farmerEndBalanceETH).minus(farmerStartBalanceETH);
    console.log("profit", fmt(profit), "ETH");

    const testDuration = doHardWorkWaitHours * iterations;
    console.log("Test duration", testDuration, "hours");

    const profitPercent = parseFloat(fmt(profit)) / parseFloat(fmt(depositETH));
    console.log("profit percent", profitPercent * 100, "%");

    const dailyYield = (profitPercent / testDuration) * 24;
    console.log("daily percent yield", dailyYield * 100, "%");

    const APR = dailyYield * 365;
    console.log("APR", APR * 100, "%");

    const APY = ((1 + dailyYield) ^ 365) - 1;
    console.log("APY", APY * 100, "%");

    console.log("LiquidityNexus USDC end balance", fmt(await USDC.balanceOf(nexus.options.address)));

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

async function TEMP_DELETE_BEFORE_DEPLOYMENT(nexusOwner) {
  const NexusLPSushi = require("../../temp_delete_before_deployment/contracts/NexusLPSushi.sol/NexusLPSushi.json");
  const NexusLPSushiContract = new web3.eth.Contract(NexusLPSushi.abi, "");
  return NexusLPSushiContract.deploy({ data: NexusLPSushi.bytecode, arguments: [] }).send({ from: nexusOwner });
}
