const config = require('./import/wstETH_rETH_sfrxETH.config.json');
const { AuraULTest } = require("./utils/ul.test.js");

//This test was developed at blockNumber 16854800
const Strategy = artifacts.require("AuraStrategyMainnet_wstETH_rETH_sfrxETH");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Aura wstETH-rETH-sfrxETH pool", function() {
  let auraULTest = new AuraULTest();

  before(async function() {
    const result = await auraULTest.setupTest(
      config.lpTokens.wstETH_rETH_sfrxETH.address, 
      config.lpTokens.wstETH_rETH_sfrxETH.whale,
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
