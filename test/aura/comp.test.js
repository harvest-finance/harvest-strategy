const config = require('./import/comp.config.json');
const { AuraULTest } = require("./utils/ul.test.js");

//This test was developed at blockNumber 13727630
const Strategy = artifacts.require("AuraStrategyMainnet_COMP");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Aura auraB-50COMP-50WETH pool", function() {
  let auraULTest = new AuraULTest();

  before(async function() {
    const result = await auraULTest.setupTest(
      config.lpTokens.B_50COMP_50WETH.address, 
      config.lpTokens.B_50COMP_50WETH.whale,
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
