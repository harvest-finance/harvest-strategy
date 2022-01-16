const { ConvexULTest } = require("./util/convex-ul-test.js");

const crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

//This test was developed at blockNumber 14005054
const strategyArtifact = artifacts.require("ConvexStrategyEURT_USDMainnet");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex EURT_USD", function() {
  // test setup
  const underlying = "0x3b6831c0077a1e44ED0a21841C3bC4dC11bCE833";
  const underlyingWhale = "0xA75204De25E91F82c5B0B849B247515153AC61e9";
  const dai = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
  const liquidationPaths = [
    {"sushi": [cvx, weth]},
    {"sushi": [crv, weth]},
    {"sushi": [weth, dai]}
  ];

  let convexULTest = new ConvexULTest();

  before(async () => {
    await convexULTest.setupTest(underlying, underlyingWhale, liquidationPaths, strategyArtifact);
  });

  describe("--------- Happy path --------------", () => {
    it("Farmer should earn money", async () => {
      await convexULTest.testHappyPath();
    });
  });
});
