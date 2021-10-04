// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
const IOneInchLiquidator = artifacts.require("IOneInchLiquidator");

const Strategy = artifacts.require("OneInchStrategy_DAI_LDO");

// This test was developed at blockNumber 13352188

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet DAI/LDO", function() {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  const underlyingWhale = "0x37e46caEfEF61D30E680cf754998B4A39e5d8325";
  const oneInchLiquidatorAddr = "0xA6031a6D87b82B2d60df9B78E578537a2AeAe93a";
  const daiStEthPoolOneInch = "0xC1A900Ae76dB21dC5aa8E418Ac0F4E888A4C7431";
  let oneInchLiquidator;

  // parties in the protocol
  let governance;
  let farmer1;

  // numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let controller;
  let vault;

  async function setupExternalContracts() {
    underlying = await IERC20.at("0xC1A900Ae76dB21dC5aa8E418Ac0F4E888A4C7431");
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

    let oneInch = "0x111111111117dC0aa78b770fA6A738034120C302";
    let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    let ldo = "0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32";
    let dai = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
    let stEth = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84";

    await setupExternalContracts();
    [controller, vault, strategy] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": Strategy,
      "strategyArtifactIsUpgradable": true,
      "underlying": underlying,
      "governance": governance,
      "liquidation": [{"1inch": [oneInch, weth]},
                      {"sushi": [ldo, weth]},
                      {"sushi": [weth, dai]},
                      {"1inch": [dai, stEth]},
                    ]
    });

    oneInchLiquidator = await IOneInchLiquidator.at(oneInchLiquidatorAddr);
    // // change pool for 1inch Liquidator to dai-stETH Pool
    await oneInchLiquidator.changePool(dai, stEth, daiStEthPoolOneInch, {from: governance});

    // whale send underlying to farmers
    await setupBalance();
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let blocksPerHour = 2400;
      let oldSharePrice;
      let newSharePrice;
      for (let i = 0; i < hours; i++) {
        console.log("loop ", i);
        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log("old shareprice: ", oldSharePrice.toFixed());
        console.log("new shareprice: ", newSharePrice.toFixed());
        console.log("growth: ", newSharePrice.toFixed() / oldSharePrice.toFixed());

        let apr = (newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))*365;
        let apy = ((newSharePrice.toFixed()/oldSharePrice.toFixed()-1)*(24/(blocksPerHour/272))+1)**365;

        console.log("instant APR:", apr*100, "%");
        console.log("instant APY:", (apy-1)*100, "%");

        await Utils.advanceNBlock(blocksPerHour);
      }
      await vault.withdraw(farmerBalance, { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      Utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      apr = (farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))*365;
      apy = ((farmerNewBalance.toFixed()/farmerOldBalance.toFixed()-1)*(24/(blocksPerHour*hours/272))+1)**365;

      console.log("earned!");
      console.log("Overall APR:", apr*100, "%");
      console.log("Overall APY:", (apy-1)*100, "%");


    });
  });
});
