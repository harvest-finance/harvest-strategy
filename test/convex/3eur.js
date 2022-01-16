const { ConvexULTest } = require("./util/convex-ul-test.js");

const crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

//This test was developed at blockNumber 14005054
const strategyArtifact = artifacts.require("ConvexStrategy3EURMainnet");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex 3EUR", function() {
  // test setup
  const underlying = "0xb9446c4Ef5EBE66268dA6700D26f96273DE3d571";
  const underlyingWhale = "0xaf07eBA6f1421F18DcAbfA5172887dEc46b2A2Ef";
  const eurt = "0xC581b735A1688071A1746c968e0798D642EDE491";
  const angle = "0x31429d1856aD1377A8A0079410B297e1a9e214c2";
  const liquidationPaths = [
    {"sushi": [cvx, weth]},
    {"sushi": [crv, weth]},
    {"sushi": [angle, weth]},
    {"uniV3": [weth, eurt]}
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
