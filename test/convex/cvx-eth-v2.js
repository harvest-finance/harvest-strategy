const { ConvexULTest } = require("./util/convex-ul-test.js");

const IFeeForwarder = artifacts.require("IFeeRewardForwarderV6");
const addresses = require("../test-config.js");

const crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

//This test was developed at blockNumber 15796660
const strategyArtifact = artifacts.require("ConvexStrategyCVX_ETHMainnetV2");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex CVX-ETH", function() {
  // test setup
  const underlying = "0x3A283D9c08E8b55966afb64C515f5143cf907611";
  const underlyingWhale = "0xD3B613a48E6fD288571B81bE3e8103A8E4C3e7A5";
  const liquidationPaths = [
    {"sushi": [crv, weth, cvx]},
  ];

  let convexULTest = new ConvexULTest();

  before(async () => {
    const result = await convexULTest.setupTest(underlying, underlyingWhale, liquidationPaths, strategyArtifact);

    const sushidex = "0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a";
    const bancordex = "0x4bf11b89310db45ea1467e48e832606a6ec7b8735c470fff7cf328e182a7c37e";

    const feeForwarder = await IFeeForwarder.at(await result.controller.feeRewardForwarder());
    await feeForwarder.configureLiquidation(
      [cvx, weth, addresses.FARM],
      [sushidex, bancordex],
      {from: result.governance}
    );
  });

  describe("--------- Happy path --------------", () => {
    it("Farmer should earn money", async () => {
      await convexULTest.testHappyPath();
    });
  });
});
