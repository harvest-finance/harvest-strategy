const config = require('./import/rETH_BADGER.config.json');
const { AuraULTest } = require("./utils/ul.test.js");

//This test was developed at blockNumber 16854800
const Strategy = artifacts.require("AuraStrategyMainnet_rETH_BADGER");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Aura rETH-BADGER pool", function() {
  let auraULTest = new AuraULTest();

  before(async function() {
    const result = await auraULTest.setupTest(
      config.lpTokens.rETH_BADGER.address, 
      config.lpTokens.rETH_BADGER.whale,
      [{"uniV3": [config.relatedTokens.weth, config.relatedTokens.reth]}],
      [],
      Strategy
    );
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      await auraULTest.testHappyPath(config.relatedTokens.aura, true);
    });
  });
});
