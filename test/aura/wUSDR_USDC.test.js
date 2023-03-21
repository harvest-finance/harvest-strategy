const config = require('./import/wUSDR_USDC.config.json');
const { AuraULTest } = require("./utils/ul.test.js");

//This test was developed at blockNumber 16854800
const Strategy = artifacts.require("AuraStrategyMainnet_wUSDR_USDC");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Aura wUSDR-USDC pool", function() {
  let auraULTest = new AuraULTest();

  before(async function() {
    const result = await auraULTest.setupTest(
      config.lpTokens.wUSDR_USDC.address, 
      config.lpTokens.wUSDR_USDC.whale,
      [],
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
