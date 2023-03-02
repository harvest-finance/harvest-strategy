const { ConvexULTest } = require("./util/convex-ul-test.js");

const crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

//This test was developed at blockNumber 15796660
const strategyArtifact = artifacts.require("ConvexStrategyTBTC2Mainnet");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex TBTC2", function() {
  // test setup
  const underlying = "0xfa65aa60a9D45623c57D383fb4cf8Fb8b854cC4D";
  const underlyingWhale = "0x2deb3882b844BD83360BbeaF7d901e59664Df204";
  const liquidationPaths = [
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
