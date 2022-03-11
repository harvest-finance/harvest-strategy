// Utilities
const Utils = require("../utilities/Utils.js");
const { impersonates, setupCoreProtocol, depositVault } = require("../utilities/hh-utils.js");

const addresses = require("../test-config.js");
const BigNumber = require("bignumber.js");
const IERC20 = artifacts.require("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");

const Strategy = artifacts.require("EightyEightMphStrategyMainnet_UNI");
const IPercentageFeeModel = artifacts.require("IPercentageFeeModel");
const IOracleMainnet = artifacts.require("IOracleMainnet");
const IxMph = artifacts.require("IxMph");

const D18 = new BigNumber(Math.pow(10, 18));

const IFeeRewardForwarder = artifacts.require("IFeeRewardForwarderV6");

//This test was developed at blockNumber 13880860

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet 88mph UNI single asset fixed yield farming", () => {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  const underlyingWhale = "0xE6227c1D47D2e55eE0EA3600AE0CdB3Bd4b9bb5C";
  const underlyingWhale2 = "0xc6db1db370fb85B72610947E536c3e7599b42e72";
  const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const mph = "0x8888801aF4d980682e47f1A9036e589479e835C5";
  const xMph = "0x1702F18c1173b791900F81EbaE59B908Da8F689b";

  let priceOracleAddr = "0x48DC32eCA58106f06b41dE514F29780FFA59c279";
  let priceOracle;

  let feeForwarder;
  let unidex = "0xde2d1a51640f78257713031680d1f306297d957426e912ab21317b9cc9495a41";

  const percentageFeeModelContract = "0x9c2ae492ec3A49c769bABffC9500256749404f8E";

  // parties in the protocol
  let governance;
  let farmer1;
  let farmer2;

  // numbers used in tests
  let farmerBalance;

  // Core protocol contracts
  let controller;
  let vault;
  let strategy;
  let potPool;

  let farmerInitialBalance;

  async function setupExternalContracts() {
    underlying = await IERC20.at("0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984");
    console.log("Fetching Underlying at: ", underlying.address);
    priceOracle = await IOracleMainnet.at(priceOracleAddr);
  }

  async function setupBalance(){
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await web3.eth.sendTransaction({ from: etherGiver, to: underlyingWhale, value: 10e18});
    await web3.eth.sendTransaction({ from: etherGiver, to: underlyingWhale2, value: 10e18});
    await web3.eth.sendTransaction({ from: etherGiver, to: governance, value: 10e18});

    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, { from: underlyingWhale });
    const farmer2Balance = await underlying.balanceOf(underlyingWhale2);
    await underlying.transfer(farmer2, farmer2Balance, { from: underlyingWhale2 });
  }

  before(async () => {
    governance = "0xf00dD244228F51547f0563e60bCa65a30FBF5f7f";
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];
    farmer2 = accounts[2];

    // impersonate accounts
    await impersonates([governance, underlyingWhale, underlyingWhale2]);

    await setupExternalContracts();

    // whale send underlying to farmers
    await setupBalance();

    [controller, vault, strategy, potPool] = await setupCoreProtocol({
      "existingVaultAddress": null,
      "strategyArtifact": Strategy,
      "strategyArtifactIsUpgradable": true,
      "underlying": underlying,
      "governance": governance,
      "liquidation": [
        {"sushi": [mph, weth]}, 
        {"uniV3": [weth, underlying.address]}, 
        {"uniV3": [underlying.address, weth]}
      ],
      "rewardPool" : true,
      "rewardPoolConfig": {
        type: 'PotPool',
        rewardTokens: [
          addresses.IFARM,
          xMph
        ]
      },
    });

    await strategy.setPotPool(potPool.address, {from: governance});
    await potPool.setRewardDistribution([strategy.address], true, {from: governance});

    feeForwarder = await IFeeRewardForwarder.at(await controller.feeRewardForwarder());
    await feeForwarder.configureLiquidation(
      [weth, addresses.FARM],
      [unidex],
      {from: governance}
    );
  });

  describe("Happy path", () => {
    it("Farmer should earn money... and more!", async () => {
      // make sure deposit and topup deposit works as expected
      await setupInitialDeposit();
      // simulate early withdrawal fee waived by 88mph
      await waiveEarlyWithdrawalFee();

      // this is where we check if farmer earns money:
      await doHardWorksUntilMaturation();

      // ensure users can still interact if maturation has been reached
      await checkAfterMaturationActions();

      // rollover the deposit after maturation
      await rolloverDeposit();
    });
  });

  async function setupInitialDeposit() {
    console.log('\n\n 1. Creating an initial deposit and running doHardWork');

    // set maturation to 7 days
    await strategy.setMaturationTarget(60*60*24*7, { from: governance });
    console.log('maturation target set to 7 days:', (await strategy.maturationTarget()).toString());

    // 1. create an initial deposit and run doHardWork to get a depositId for the strategy
    farmerInitialBalance = new BigNumber(await underlying.balanceOf(farmer1));
    // create an initial deposit with half the farmer balance
    await depositVault(farmer1, underlying, vault, farmerInitialBalance.dividedBy(2));

    // we also deposit from another farmer to ensure the strategy is left with some funds after farmer1 withdraws
    // which is a realistic scenario. Rollovers are not supported by 88mph if the deposit is left without funds.
    // see the comment in EightyEightMphStrategy.sol in rolloverDeposit method for more info.
    await depositVault(farmer2, underlying, vault, await underlying.balanceOf(farmer2), {from: farmer2});

    // run doHardWork
    await controller.doHardWork(vault.address, { from: governance });

    // check depositId
    const depositId = await strategy.depositId();
    console.log(" ------ created depositId: ", depositId.toString());
    console.log("Farmer Balance in vault after deposit", (await vault.balanceOf(farmer1)).toString());
    console.log("Farmer 2 Balance in vault after deposit", (await vault.balanceOf(farmer2)).toString());

    // top up the deposit with the rest of the balance
    const farmerRestBalance = new BigNumber(await underlying.balanceOf(farmer1));
    await depositVault(farmer1, underlying, vault, farmerRestBalance);

    const depositIdAfterTopUp = await strategy.depositId();
    console.log("------- depositId after top-up: ", depositIdAfterTopUp.toString());
    // make sure depositId stayed the same
    Utils.assertBNEq(depositId, depositIdAfterTopUp);

    // run doHardWork
    await controller.doHardWork(vault.address, { from: governance });
    console.log("Farmer Balance in vault after top-up", (await vault.balanceOf(farmer1)).toString());
  }

  async function waiveEarlyWithdrawalFee() {
    console.log("\n\n 2. waiving early withdrawal fee");
     // 2. waive the early withdrawal fee for the depositId
     const feeModel = await IPercentageFeeModel.at(percentageFeeModelContract);
     const feeModelOwner = await feeModel.owner();
     // impersonate owner of the contract
     let etherGiver = accounts[9];
     await impersonates([governance, underlyingWhale, underlyingWhale2, feeModelOwner]);
     await web3.eth.sendTransaction({ from: etherGiver, to: feeModelOwner, value: 10e18});
 
     const depositId = await strategy.depositId();
     const earlyWithdrawalFeeBefore = await feeModel.getEarlyWithdrawFeeAmount(
       await strategy.rewardPool(),
       depositId,
       await vault.balanceOf(farmer1), 
       { from: feeModelOwner }
     );
     console.log("\n\n early withdrawal fee before set to:", earlyWithdrawalFeeBefore.toString());
 
     // waive fee
     await feeModel.overrideEarlyWithdrawFeeForDeposit(await strategy.rewardPool(), depositId, 0, { from: feeModelOwner });
     // ensure fee was waived successfully
     const earlyWithdrawalFee = await feeModel.getEarlyWithdrawFeeAmount(
       await strategy.rewardPool(),
       depositId,
       await vault.balanceOf(farmer1), 
       { from: feeModelOwner }
     );
     console.log("new early withdrawal fee set to:", earlyWithdrawalFee.toString());
 
     Utils.assertBNEq(earlyWithdrawalFee, 0);
  }

  async function doHardWorksUntilMaturation() {
    // 3. simulate doHardWorks until maturation is reached
    console.log("\n\n 3. simulate doHardWorks and reach maturation");

    let fTokenBalance = new BigNumber(await vault.balanceOf(farmer1));

    let erc20Vault = await IERC20.at(vault.address);
    await erc20Vault.approve(potPool.address, fTokenBalance, {from: farmer1});
    await potPool.stake(fTokenBalance, {from: farmer1});

    // Using half days is to simulate how we doHardwork in the real world
    const hours = 10;
    const blocksPerHour = 2400;
    const xMphHodl = await IxMph.at(xMph);
    const farmerOldXMph = new BigNumber(await xMphHodl.balanceOf(farmer1));
    
    let oldSharePrice;
    let newSharePrice;

    for (let i = 0; i < hours; i++) {
      console.log("\n --------- loop ", i);

      oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
      oldHodlSharePrice = new BigNumber(await xMphHodl.getPricePerFullShare());
      oldPotPoolBalance = new BigNumber(await xMphHodl.balanceOf(potPool.address));
      await controller.doHardWork(vault.address, {from: governance});
      newSharePrice = new BigNumber(await vault.getPricePerFullShare());
      newHodlSharePrice = new BigNumber(await xMphHodl.getPricePerFullShare());
      newPotPoolBalance = new BigNumber(await xMphHodl.balanceOf(potPool.address));

      mphPrice = new BigNumber(await priceOracle.getPrice(mph));
      underlyingPrice = new BigNumber(await priceOracle.getPrice(underlying.address));
      console.log("MPH price:", mphPrice.toFixed()/D18.toFixed());
      console.log("Underlying price:", underlyingPrice.toFixed()/D18.toFixed());

      oldValue = (fTokenBalance.times(oldSharePrice).times(underlyingPrice)).div(1e36).plus((oldPotPoolBalance.times(oldHodlSharePrice).times(mphPrice)).div(1e36));
      newValue = (fTokenBalance.times(newSharePrice).times(underlyingPrice)).div(1e36).plus((newPotPoolBalance.times(newHodlSharePrice).times(mphPrice)).div(1e36));

      console.log("old value: ", oldValue.toFixed()/D18.toFixed());
      console.log("new value: ", newValue.toFixed()/D18.toFixed());
      console.log("growth: ", newValue.toFixed() / oldValue.toFixed());

      console.log("xMPH in potpool: ", newPotPoolBalance.toFixed());

      apr = (newValue.toFixed()/oldValue.toFixed()-1)*(24/(blocksPerHour/272))*365;
      apy = ((newValue.toFixed()/oldValue.toFixed()-1)*(24/(blocksPerHour/272))+1)**365;

      console.log("instant APR:", apr*100, "%");
      console.log("instant APY:", (apy-1)*100, "%");

      await Utils.advanceNBlock(blocksPerHour);
    }

    console.log('\n ------------------- LOOPS COMPLETED ---------- \n');

    // withdrawAll to make sure no doHardwork is called when we do withdraw later.
    await vault.withdrawAll({ from: governance });

    // wait until all reward can be claimed by the farmer and maturation is reached
    await Utils.waitTime(86400 * 30 * 1000);
    console.log("vaultBalance: ", fTokenBalance.toFixed());

    await potPool.exit({from: farmer1});
    // ensure user can withdraw
    await vault.withdraw(fTokenBalance.toFixed(), { from: farmer1 });
    let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
    let farmerNewXMph = new BigNumber(await xMphHodl.balanceOf(farmer1));
    Utils.assertBNGt(farmerNewBalance, farmerBalance);
    Utils.assertBNGt(farmerNewXMph, farmerOldXMph);

    oldValue = (new BigNumber(farmerBalance).times(1e18).times(underlyingPrice)).div(1e36).plus((farmerOldXMph.times(newHodlSharePrice).times(mphPrice)).div(1e36));
    newValue = (farmerNewBalance.times(1e18).times(underlyingPrice)).div(1e36).plus((farmerNewXMph.times(newHodlSharePrice).times(mphPrice)).div(1e36));

    apr = (newValue.toFixed()/oldValue.toFixed()-1)*(24/(blocksPerHour*hours/272))*365;
    apy = ((newValue.toFixed()/oldValue.toFixed()-1)*(24/(blocksPerHour*hours/272))+1)**365;

    console.log("Overall APR:", apr*100, "%");
    console.log("Overall APY:", (apy-1)*100, "%");

    console.log("potpool totalShare: ", (new BigNumber(await potPool.totalSupply())).toFixed());
    console.log("xMPH in potpool: ", (new BigNumber(await xMphHodl.balanceOf(potPool.address))).toFixed());
    console.log("Farmer had initially xMPH: ", farmerOldXMph.toFixed());
    console.log("Farmer got xMPH from potpool: ", (farmerNewXMph - farmerOldXMph).toFixed());
    console.log("EARNED! --------------------------- \n\n");

    await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
  }

  async function checkAfterMaturationActions() {
    console.log('\n\n 4. Ensure interactions work as expected after maturation:');
    // after maturation is reached, doHardWorks should revert and alert to rollover the deposit
    try{
      console.log('------- running hard work that is expected to revert because deposit must be rolled over:');
      await controller.doHardWork(vault.address, {from: governance});
    } catch(ex) {
      console.log('hardWork Failed successfully ;) THIS ERROR IS EXPECTED AND PART OF THIS TEST, ALL GOOD, CHILL: \n', ex);
    }
    
    console.log('\n -------- Try to deposit as farmer after maturation');
    let currentFarmerBalance = (await vault.balanceOf(farmer1)).toString();
    console.log("Farmer Balance in vault before deposit", currentFarmerBalance);
    // ensure user can topup deposit after maturation has been reached
    // farmer has already withdrawn everything at this point
    const farmerCurrentBalance = new BigNumber(await underlying.balanceOf(farmer1));
    // create an initial deposit with half the farmer balance
    await depositVault(farmer1, underlying, vault, farmerCurrentBalance.dividedBy(2));
    currentFarmerBalance = (await vault.balanceOf(farmer1)).toString();
    console.log("Farmer Balance in vault after deposit", currentFarmerBalance);
    Utils.assertBNGt(currentFarmerBalance, 0);
  }
  
  async function rolloverDeposit() {
    // 5. rolloverDeposit
    console.log('\n\n 5. Rolling over deposit:');
    const currentFarmerBalance = (await vault.balanceOf(farmer1)).toString();
     
    const oldDepositId = await strategy.depositId();
    // set manual required flag to signal deposit is ready to be rolled over with the next doHardWork
    await strategy.setShouldRolloverDeposit(true, { from: governance });
    // hardWork will trigger rolloverDeposit
    // note that here this will actually create a new deposit rather than rolling over the old deposit
    // because at this moment all funds are sitting in the vault because of withdrawAllToVault
    // so the old deposit is drained and can not be topped up after deposit
    await controller.doHardWork(vault.address, {from: governance});

    // ensure depositId has changed
    const depositId = await strategy.depositId();
    Utils.assertNEqBN(depositId, oldDepositId);
    // ensure farmer still has the same balance
    let newFarmerBalance = (await vault.balanceOf(farmer1)).toString();
    Utils.assertBNEq(currentFarmerBalance, newFarmerBalance);
    
    console.log('rollover with create new deposit successful!')

    // wait until maturation is reached
    await Utils.waitTime(86400 * 30 * 1000);
    // try to run an actual manual rollover deposit now that the deposit is left with funds
    await strategy.rolloverDeposit(true, {from: governance});

    // ensure depositId has changed
    const newDepositId = await strategy.depositId();
    Utils.assertNEqBN(depositId, newDepositId);
    // ensure farmer still has the same balance
    newFarmerBalance = (await vault.balanceOf(farmer1)).toString();
    Utils.assertBNEq(currentFarmerBalance, newFarmerBalance);
    console.log('actual rollover successful!')
  }
});
