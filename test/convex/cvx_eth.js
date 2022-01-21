const { ConvexULTest } = require("./util/convex-ul-test.js");

const IFeeForwarder = artifacts.require("IFeeRewardForwarderV6");
const addresses = require("../test-config.js");

const crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

//This test was developed at blockNumber 14005054
const strategyArtifact = artifacts.require("ConvexStrategyCVX_ETHMainnet");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex CVX_ETH", () => {
  // test setup
  const underlying = "0x3A283D9c08E8b55966afb64C515f5143cf907611";
  const underlyingWhale = "0x38eE5F5A39c01cB43473992C12936ba1219711ab";
  const liquidationPaths = [
    {"sushi": [crv, weth, cvx]},
  ];

  let convexULTest = new ConvexULTest();

  before(async () => {
    const result = await convexULTest.setupTest(underlying, underlyingWhale, liquidationPaths, strategyArtifact);

    const sushidex = "0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a";
    const unidex = "0xde2d1a51640f78257713031680d1f306297d957426e912ab21317b9cc9495a41";

    const feeForwarder = await IFeeForwarder.at(await result.controller.feeRewardForwarder());
    await feeForwarder.configureLiquidation(
      [cvx, weth, addresses.FARM],
      [sushidex, unidex],
      {from: result.governance}
    );
  });

  describe("--------- Happy path --------------", () => {
    it("Farmer should earn money", async () => {
      await convexULTest.testHappyPath();
    });
  });
});
