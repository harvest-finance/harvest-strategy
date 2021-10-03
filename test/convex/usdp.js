// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const IBooster = artifacts.require("IBooster");

const Strategy = artifacts.require("ConvexStrategyUSDPMainnet");
const IUniV3Dex = artifacts.require("IUniV3Dex");

//This test was developed at blockNumber 13340787

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex USDP", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  let underlyingWhale = "0x0C043aEf7D5DDafac053e0269e97a8ed918451f1";
  let crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
  let cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
  let dai = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
  let duck = "0x92E187a03B6CD19CB6AF293ba17F2745Fd2357D5";
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let hodlVault = "0xF49440C1F012d041802b25A73e5B0B9166a75c02";  
  let uniV3DexAddr = "0x1D35ba854575B576B3C0aB4e64E27Bf2D2c1D48A";
  let uniV3Dex = "0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f";
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
    underlying = await IERC20.at("0x7Eb40E450b9655f4B3cC4259BCC731c63ff55ae6");
    console.log("Fetching Underlying at: ", underlying.address);
  }

  async function setupBalance(){
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await web3.eth.sendTransaction({ from: etherGiver, to: underlyingWhale, value: 1e18});

    farmerBalance = new BigNumber(await underlying.balanceOf(underlyingWhale));
    console.log('transfering farmerBalance', farmerBalance.toFixed());
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
      "existingVaultAddress": "0x02d77f6925f4ef89EE2C35eB3dD5793f5695356f",
      "strategyArtifact": Strategy,
      "strategyArtifactIsUpgradable": true,
      "upgradeStrategy": true,
      "underlying": underlying,
      "governance": governance,
      "liquidation": [{"sushi": [cvx, weth]},
                      {"sushi": [crv, weth]},
                      {"sushi": [weth, dai]},
                      {"uniV3": [duck, weth]}],
    });

    uniV3Dex = await IUniV3Dex.at(uniV3DexAddr);
    await uniV3Dex.setFee(duck, weth, 10000, {from: governance});

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
