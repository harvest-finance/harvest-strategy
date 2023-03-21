const config = require('./import/auraBALStable.config.json');
const { AuraULTest } = require("./utils/ul.test.js");

//This test was developed at blockNumber 13727630
const Strategy = artifacts.require("AuraStrategyMainnet_auraBALStable");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Aura auraB-auraBAL-STABLE pool", function() {
  let auraULTest = new AuraULTest();

  before(async function() {
    const result = await auraULTest.setupTest(
      config.lpTokens.B_auraBAL_STABLE.address, 
      config.lpTokens.B_auraBAL_STABLE.whale,
      [{"balancer": [config.relatedTokens.aura, config.relatedTokens.wETH]}, 
       {"balancer": [config.relatedTokens.wETH, config.relatedTokens.auraBAL]}], 
      config.setLiquidationPath,
      Strategy);
  });

  describe("Happy path", function() {
    it("Farmer should earn money", async function() {
      await auraULTest.testHappyPath(config.relatedTokens.aura, true);
    });
  });
});
