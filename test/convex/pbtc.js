const { ConvexULTest } = require("./util/convex-ul-test.js");

const crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const pnt = "0x89Ab32156e46F46D02ade3FEcbe5Fc4243B9AAeD";

//This test was developed at blockNumber 15983140
const strategyArtifact = artifacts.require("ConvexStrategyPBTCMainnet");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex pBTC", function() {
  // test setup
  const underlying = "0xC9467E453620f16b57a34a770C6bceBECe002587";
  const underlyingWhale = "0x36b9bB0Fb89f8E74251E45b6d9BbA2926560028A";
  const liquidationPaths = [{"uni": [pnt, weth]},
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
