const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const Strategy = artifacts.require("NexusLPSushiStrategy");

describe("LiquidityNexus: SUSHI:WETH", () => {
  const deadline = "99999999999";
  const usdcWhale = "0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8"; // binance7

  // parties in the protocol
  const governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f"; // Harvest.finance deployer
  let nexusOwner;
  let farmer;

  // Core protocol contracts
  let controller;
  let vault;
  let strategy;

  let nexus;

  const ethToDeposit = ethers.utils.parseEther("2000.0");

  before(async function () {
    const accounts = await web3.eth.getAccounts();
    nexusOwner = accounts[0];
    farmer = accounts[1];
    await impersonates([governance, usdcWhale]);

    const NexusLPSushi = require("../../temp_delete_before_deployment/contracts/NexusLPSushi.sol/NexusLPSushi.json");
    const NexusLPSushiContract = new web3.eth.Contract(NexusLPSushi.abi, "", { from: nexusOwner });
    nexus = await NexusLPSushiContract.deploy({ data: NexusLPSushi.bytecode, arguments: [] }).send();

    [controller, vault, strategy] = await setupCoreProtocol({
      existingVaultAddress: null,
      strategyArtifact: Strategy,
      strategyArtifactIsUpgradable: true,
      governance: governance,
      strategyArgs: [addresses.Storage, nexus.options.address, "vaultAddr"],
      underlying: { address: nexus.options.address },
    });
    nexus.methods.setGovernance(strategy.address).send();

    await supplyCapitalAsDeployer();
  });

  async function supplyCapitalAsDeployer() {
    const amount = "100000000" + "000000";
    const USDC = await IERC20.at("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");
    await USDC.transfer(nexusOwner, amount, { from: usdcWhale });

    await USDC.approve(nexus.options.address, amount, { from: nexusOwner });
    await nexus.methods.depositAllCapital().send();
  }

  it("Farmer should earn money", async () => {
    const farmerOldEthBalance = await web3.eth.getBalance(farmer);

    Utils.assertBNGt(farmerOldEthBalance, ethToDeposit);
    Utils.assertBNGt(await nexus.methods.availableSpaceToDepositETH().call(), ethToDeposit);
    await nexus.methods.addLiquidityETH(farmer, deadline).send({ value: ethToDeposit, from: farmer });

    const farmerOldLPBalance = await nexus.methods.balanceOf(farmer).call();
    await nexus.methods.approve(vault.address, farmerOldLPBalance).send({from:farmer});
    await vault.deposit(farmerOldLPBalance, {from: farmer});

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
      console.log(newSharePrice);

      newSharePrice = newSharePrice.multipliedBy(await nexus.methods.pricePerFullShare().call()).div(1e18);

      console.log("old shareprice: ", oldSharePrice.toFixed());
      console.log("new shareprice: ", newSharePrice.toFixed());
      console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());

      await Utils.advanceNBlock(blocksPerHour);
    }
    const vaultBalance = new BigNumber(await vault.balanceOf(farmer));
    console.log("vaultBalance: ", vaultBalance.toFixed());

    await vault.withdraw(vaultBalance.toFixed(), { from: farmer });
    let farmerNewLPBalance = await nexus.methods.balanceOf(farmer).call();

    await nexus.methods.removeAllLiquidityETH(farmer,deadline).send({from: farmer});

    let farmerNewEthBalance = await web3.eth.getBalance(farmer);

    console.log("a.toString()!!!!");
    console.log(farmerNewEthBalance.toString());
    console.log(farmerOldEthBalance.toString());

    Utils.assertBNGt(farmerNewEthBalance, farmerOldEthBalance);

    console.log("earned!");

    await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
  });
});
