const { ConvexULTest } = require("./util/convex-ul-test.js");


const crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

//This test was developed at blockNumber 14005054
const strategyArtifact = artifacts.require("ConvexStrategyUST_WORMHOLEMainnet");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex UST_WORMHOLE", function() {
  // test setup
  const underlying = "0xCEAF7747579696A2F0bb206a14210e3c9e6fB269";
  const underlyingWhale = "0xA046a8660E66d178eE07ec97c585eeb6aa18c26C";
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
