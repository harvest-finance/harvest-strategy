const config = require('./import/bbiUSD.config.json');
const { AuraULTest } = require("./utils/ul.test.js");

//This test was developed at blockNumber 16742970
const Strategy = artifacts.require("AuraStrategyMainnet_bbiUSD");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Aura aurabb-i-USD pool", function() {
  let auraULTest = new AuraULTest();

  before(async function() {
    const result = await auraULTest.setupTest(
      config.lpTokens.bb_i_USD.address, 
      config.lpTokens.bb_i_USD.whale,
      [{"balancer": [config.relatedTokens.aura, config.relatedTokens.wETH]}], 
      config.setLiquidationPath,
      Strategy);
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      await auraULTest.testHappyPath(config.relatedTokens.aura, true);
    });
  });
});
