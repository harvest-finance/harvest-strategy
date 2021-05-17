// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

//const Strategy = artifacts.require("");
const IdleStrategyDAIMainnet = artifacts.require("IdleStrategyDAIMainnet");
const IVault = artifacts.require("IVault");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet IDLE DAI", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup, block number: 12323239
  let underlyingWhale = "0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503";
  let stkAaveHolder = "0xdb5aa12ad695ef2a28c6cdb69f2bb04bed20a48e";
  let stkAave = "0x4da27a545c0c5B758a6BA100e3a049001de870f5";

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
    underlying = await IERC20.at("0x6B175474E89094C44Da98b954EedeAC495271d0F");
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

    // impersonate accounts
    await impersonates([governance, underlyingWhale, stkAaveHolder]);

    await setupExternalContracts();
    [controller, vault, strategy] = await setupCoreProtocol({
      "existingVaultAddress": "0xab7fa2b2985bccfc13c6d86b1d5a17486ab1e04c",
      "strategyArtifact": IdleStrategyDAIMainnet,
      "announceStrategy": true,
      "underlying": underlying,
      "governance": governance,
    });

    stkAaveToken = await IERC20.at(stkAave);

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);

      await stkAaveToken.transfer(strategy.address, "10" + "000000000000000000", {from: stkAaveHolder});

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let oldSharePrice;
      let newSharePrice;
      for (let i = 0; i < hours; i++) {
        //put some stkAave into the strategy every loop to simulate rewards
        await stkAaveToken.transfer(strategy.address, "1" + "000000000000000000", {from: stkAaveHolder});
        console.log("loop ", i);
        let blocksPerHour = 9600; //longer loops to test aave cooldown
        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await vault.doHardWork({ from: governance });
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
