const config = require('./import/PENDLE_ETH.config.json');
const { AuraULTest } = require("./utils/ul.test.js");

//This test was developed at blockNumber 16854800
const Strategy = artifacts.require("AuraStrategyMainnet_PENDLE_ETH");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Aura PENDLE-ETH pool", function() {
  let auraULTest = new AuraULTest();

  before(async function() {
    const result = await auraULTest.setupTest(
      config.lpTokens.PENDLE_ETH.address, 
      config.lpTokens.PENDLE_ETH.whale,
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
