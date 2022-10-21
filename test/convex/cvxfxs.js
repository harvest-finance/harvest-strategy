const { ConvexULTest } = require("./util/convex-ul-test.js");

const crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

//This test was developed at blockNumber 15796660
const strategyArtifact = artifacts.require("ConvexStrategyCvxFXSMainnet");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex cvxFXS", function() {
  // test setup
  const underlying = "0xF3A43307DcAFa93275993862Aae628fCB50dC768";
  const underlyingWhale = "0x94712699C06Ec46b09f31B1aECd078049Dad3Fe3";
  const fxs = "0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0";
  const liquidationPaths = [
    {'sushi': [fxs, weth]},
    {'sushi': [weth, fxs]}
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
