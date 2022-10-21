const { ConvexULTest } = require("./util/convex-ul-test.js");

const crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

//This test was developed at blockNumber 15796660
const strategyArtifact = artifacts.require("ConvexStrategyCRV_ETHMainnetV2");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex CRV-ETH", function() {
  // test setup
  const underlying = "0xEd4064f376cB8d68F770FB1Ff088a3d0F3FF5c4d";
  const underlyingWhale = "0x28a55C4b4f9615FDE3CDAdDf6cc01FcF2E38A6b0";
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
