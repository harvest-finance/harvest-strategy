const { ConvexULTest } = require("./util/convex-ul-test.js");

const crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

//This test was developed at blockNumber 14005054
const strategyArtifact = artifacts.require("ConvexStrategyIbBTCMainnet");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex ibBTC", function() {
  // test setup
  const underlying = "0xFbdCA68601f835b27790D98bbb8eC7f05FDEaA9B";
  const underlyingWhale = "0xC8C2b727d864CC75199f5118F0943d2087fB543b";
  const wbtc = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599";
  const liquidationPaths = [
    {"sushi": [cvx, weth]},
    {"sushi": [crv, weth]},
    {"sushi": [weth, wbtc]}
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
