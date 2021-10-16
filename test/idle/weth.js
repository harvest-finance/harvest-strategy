// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const WETH9 = artifacts.require("WETH9");

//const Strategy = artifacts.require("");
const IdleStrategyWETHMainnet = artifacts.require("IdleStrategyWETHMainnet");


// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet IDLE WETH", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup, block number: 12882710
  let underlyingWhale;

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
    underlying = await IERC20.at("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance(){
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await send.ether(etherGiver, underlyingWhale, "50" + "000000000000000000");
    let weth9 = await WETH9.at("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
    await weth9.deposit({from : underlyingWhale, value: "50" + "000000000000000000"})

    // Wrap that Ether
    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, { from: underlyingWhale });
  }

  before(async function() {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    underlyingWhale = accounts[8];
    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance]);

    await setupExternalContracts();
    [controller, vault, strategy] = await setupCoreProtocol({
        "existingVaultAddress": null,
        "strategyArtifact": IdleStrategyWETHMainnet,
        "underlying": underlying,
        "governance": governance,
    });
    
    /* 
    fails with: "revert Liquidity loan must be settled first"
    
    [controller, vault, strategy] = await setupCoreProtocol({
      "existingVaultAddress": "0xFE09e53A81Fe2808bc493ea64319109B5bAa573e",
      "strategyArtifact": IdleStrategyWETHMainnet,
      "announceStrategy": true,
      "underlying": underlying,
      "governance": governance,
    });
    */

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
        //await vault.doHardWork({ from: governance });
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log("old shareprice: ", oldSharePrice.toFixed());
        console.log("new shareprice: ", newSharePrice.toFixed());
        console.log("growth: ", newSharePrice.toFixed()/oldSharePrice.toFixed());

        await Utils.advanceNBlock(blocksPerHour);
      }
      await vault.withdraw( (new BigNumber(await vault.balanceOf(farmer1))).toFixed() , { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      Utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      console.log("earned!");

    });
  });
});
