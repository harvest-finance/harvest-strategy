// Utilities
const Utils = require('../utilities/Utils.js');
const {
  impersonates,
  setupCoreProtocol,
  depositVault,
} = require('../utilities/hh-utils.js');

const BigNumber = require('bignumber.js');
const IERC20 = artifacts.require(
  '@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20'
);

const Strategy = artifacts.require('UsdcStargateStrategyMainnet');

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe('Stargate: USDC', function () {
  let accounts;

  // external contracts
  let underlying;

  // external setup
  let underlyingWhale = '0x91a88dd9c43e1e6d580abe4c54f1b6b53900a644';

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
    underlying = await IERC20.at('0xdf0770dF86a8034b3EFEf0A1Bb3c889B8332FF56');
    console.log('Fetching Underlying at: ', underlying.address);
  }

  async function setupBalance() {
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await web3.eth.sendTransaction({ from: etherGiver, to: underlyingWhale, value: '100000000000000000000', gasPrice: 1000000000000 });
    await web3.eth.sendTransaction({
      from: etherGiver,
      to: '0xf00dD244228F51547f0563e60bCa65a30FBF5f7f',
      value: '100000000000000000000',
      gasPrice: 1000000000000,
    });

    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, {
      from: underlyingWhale,
    });
  }

  before(async function () {
    governance = '0xf00dD244228F51547f0563e60bCa65a30FBF5f7f';
    accounts = await web3.eth.getAccounts();

    console.log('accounts: ', accounts);

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale]);

    await setupExternalContracts();

    // whale send underlying to farmers
    await setupBalance();

    [controller, vault, strategy] = await setupCoreProtocol({
      existingVaultAddress: null,
      strategyArtifact: Strategy,
      strategyArtifactIsUpgradable: true,
      underlying: underlying,
      governance: governance,
    });
  });

  describe('Happy path', function () {
    it('Farmer should earn money', async function () {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let oldSharePrice;
      let newSharePrice;
      for (let i = 0; i < hours; i++) {
        console.log('loop ', i);
        let blocksPerHour = 2400;
        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log('old shareprice: ', oldSharePrice.toFixed());
        console.log('new shareprice: ', newSharePrice.toFixed());
        console.log(
          'growth: ',
          newSharePrice.toFixed() / oldSharePrice.toFixed()
        );

        await Utils.advanceNBlock(blocksPerHour);
      }
      const vaultBalance = new BigNumber(await vault.balanceOf(farmer1));
      console.log('vaultBalance: ', vaultBalance.toFixed());

      await vault.withdraw(vaultBalance.toFixed(), { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      Utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      console.log('earned!');

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
