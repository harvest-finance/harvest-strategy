// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const IBooster = artifacts.require("IBooster");

const Strategy = artifacts.require("ConvexStrategyOBTCMainnet");

//This test was developed at blockNumber 13191150

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex OBTC", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  let underlyingWhale = "0x5275817b74021E97c980E95EdE6bbAc0D0d6f3a2";
  let crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
  let cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
  let bor = "0xBC19712FEB3a26080eBf6f2F7849b417FdD792CA";
  let wbtc = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599";
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let hodlVault = "0xF49440C1F012d041802b25A73e5B0B9166a75c02";
  let booster;

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
    underlying = await IERC20.at("0x2fE94ea3d5d4a175184081439753DE15AeF9d614");
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance(){
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await web3.eth.sendTransaction({ from: etherGiver, to: underlyingWhale, value: 1e18});

    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, { from: underlyingWhale });
  }

  before(async function() {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale]);

    await setupExternalContracts();
    [controller, vault, strategy] = await setupCoreProtocol({
      "existingVaultAddress": "0x966A70A4d3719A6De6a94236532A0167d5246c72",
      "strategyArtifact": Strategy,
      "strategyArtifactIsUpgradable": true,
      "upgradeStrategy": true,
      "underlying": underlying,
      "governance": governance,
      "liquidation": [{"sushi": [cvx, weth]},
                      {"sushi": [crv, weth]},
                      {"sushi": [weth, wbtc]},
                      {"uniV3": [bor, weth]}],

    });

    await strategy.setSellFloor(0, {from:governance});

    booster = await IBooster.at("0xF403C135812408BFbE8713b5A23a04b3D48AAE31");

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);
      let fTokenBalance = await vault.balanceOf(farmer1);
      let cvxToken = await IERC20.at("0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B");
      let hodlOldBalance = new BigNumber(await cvxToken.balanceOf(hodlVault));

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let blocksPerHour = 2400;
      let oldSharePrice;
      let newSharePrice;
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);

        await booster.earmarkRewards(await strategy.poolId());

        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log("old shareprice: ", oldSharePrice.toFixed());
        console.log("new shareprice: ", newSharePrice.toFixed());
        console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());

        apr = (newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))*365;
        apy = ((newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))+1)**365;

        console.log("instant APR:", apr*100, "%");
        console.log("instant APY:", (apy-1)*100, "%");

        await Utils.advanceNBlock(blocksPerHour);
      }
      await vault.withdraw(fTokenBalance, { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      Utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      let hodlNewBalance = new BigNumber(await cvxToken.balanceOf(hodlVault));
      console.log("CVX before", hodlOldBalance.toFixed());
      console.log("CVX after ", hodlNewBalance.toFixed());
      Utils.assertBNGt(hodlNewBalance, hodlOldBalance);

      apr = (farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))*365;
      apy = ((farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))+1)**365;

      console.log("earned!");
      console.log("Overall APR:", apr*100, "%");
      console.log("Overall APY:", (apy-1)*100, "%");

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
