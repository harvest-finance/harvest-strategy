const config = require('./import/stETHbbaUSD.config.json');
const { AuraULTest } = require("./utils/ul.test.js");

//This test was developed at blockNumber 13727630
const Strategy = artifacts.require("AuraStrategyMainnet_stETHBbaUSD");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Aura aura50wstETH-50bb-a-USD pool", function() {
  let auraULTest = new AuraULTest();

  before(async function() {
    const result = await auraULTest.setupTest(
      config.lpTokens.B_50wstETH_50bbaUSD.address, 
      config.lpTokens.B_50wstETH_50bbaUSD.whale,
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
