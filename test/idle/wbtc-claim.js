// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const { send } = require("@openzeppelin/test-helpers");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

//const Strategy = artifacts.require("");
const IdleStrategyWBTCMainnet = artifacts.require("IdleStrategyWBTCMainnet");
const IVault = artifacts.require("IVault");


// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet IDLE WBTC Claimable", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup, block number: 12323239
  let underlyingWhale = "0x701bd63938518d7db7e0f00945110c80c67df532";

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
    underlying = await IERC20.at("0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599");
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
    multiSig = "0xF49440C1F012d041802b25A73e5B0B9166a75c02";
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale, multiSig]);

    await setupExternalContracts();
    [controller, vault, strategy] = await setupCoreProtocol({
      "existingVaultAddress": "0x5d9d25c7C457dD82fc8668FFC6B9746b674d4EcB",
      "strategyArtifact": IdleStrategyWBTCMainnet,
      "announceStrategy": true,
      "underlying": underlying,
      "governance": governance,
    });

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      await controller.doHardWork(vault.address, { from: governance });
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let oldSharePrice;
      let newSharePrice;

      // Not selling, so doHardWork wouldn't sell rewards
      await strategy.setLiquidation(false, false, true, {from: governance});

      await strategy.setRewardClaimable(true, {from: governance});

      oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
      await controller.doHardWork(vault.address, { from: governance });
      newSharePrice = new BigNumber(await vault.getPricePerFullShare());

      let idle = await IERC20.at("0x875773784Af8135eA0ef43b5a374AaD105c5D39e");
      let comp = await IERC20.at("0xc00e94Cb662C3520282E6f5717214004A7f26888");
      let stkaave = await IERC20.at("0x4da27a545c0c5B758a6BA100e3a049001de870f5");

      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);
        let blocksPerHour = 2400;
        let idleBalanceBefore = new BigNumber(await idle.balanceOf(multiSig));
        let compBalanceBefore = new BigNumber(await comp.balanceOf(multiSig));
        let stkaaveBalanceBefore = new BigNumber(await stkaave.balanceOf(multiSig));
        await strategy.claimReward({from: multiSig});
        let idleBalanceAfter = new BigNumber(await idle.balanceOf(multiSig));
        let compBalanceAfter = new BigNumber(await comp.balanceOf(multiSig));
        let stkaaveBalanceAfter = new BigNumber(await stkaave.balanceOf(multiSig));

        console.log("idleBalanceBefore: ", idleBalanceBefore.toFixed());
        console.log("idleBalanceAfter: ", idleBalanceAfter.toFixed());
        console.log("idle diff: ", (idleBalanceAfter.minus(idleBalanceBefore)).toFixed());

        console.log("compBalanceBefore: ", compBalanceBefore.toFixed());
        console.log("compBalanceAfter: ", compBalanceAfter.toFixed());
        console.log("comp diff: ", (compBalanceAfter.minus(compBalanceBefore)).toFixed());

        console.log("stkaaveBalanceBefore: ", stkaaveBalanceBefore.toFixed());
        console.log("stkaaveBalanceAfter: ", stkaaveBalanceAfter.toFixed());
        console.log("stkaave diff: ", (stkaaveBalanceAfter.minus(stkaaveBalanceBefore)).toFixed());

        await Utils.advanceNBlock(blocksPerHour);
      }
      const vaultBalance = new BigNumber(await vault.balanceOf(farmer1));
      console.log("vaultBalance: ", vaultBalance.toFixed());

      await vault.withdraw(vaultBalance.toFixed(), { from: farmer1 });

      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      console.log("farmerOldBalance: ", farmerOldBalance.toFixed());
      console.log("farmerNewBalance: ", farmerNewBalance.toFixed());
      Utils.assertBNGte(farmerNewBalance, farmerOldBalance);
      console.log("got the same amount back");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
