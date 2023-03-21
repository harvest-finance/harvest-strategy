const config = require('./import/auraBAL.config.json');
const { AuraULTest } = require("./utils/ul.test.js");

//This test was developed at blockNumber 13727630
const Strategy = artifacts.require("AuraStrategyMainnet_auraBAL");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Aura auraBAL pool", function() {
  let auraULTest = new AuraULTest();

  before(async function() {
    const result = await auraULTest.setupTest(
      config.lpTokens.auraBAL.address, 
      config.lpTokens.auraBAL.whale,
      [{"balancer": [config.relatedTokens.aura, config.relatedTokens.wETH]}], 
      config.setLiquidationPath,
      Strategy);
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      await auraULTest.testHappyPath(config.relatedTokens.aura, false);
    });
  });
});
