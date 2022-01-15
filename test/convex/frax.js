const { ConvexULTest } = require("./util/convex-ul-test.js");

//This test was developed at blockNumber 14005054

const crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex FRAX", function() {
  // test setup
  const underlying = "0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B";
  const underlyingWhale = "0x80AF4D533d298BF79280C2C9A6646cD99925009D";
  // const underlyingWhale = "0x1dDb61FD4E70426eDb59e7ECDDf0f049d9cF3906";
  const frax = "0x853d955aCEf822Db058eb8505911ED77F175b99e";
  // const dai = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
  const liquidationPaths = [
    {"sushi": [cvx, weth]},
    {"sushi": [crv, weth]},
    {"sushi": [weth, frax]}
  ];

  let convexULTest = new ConvexULTest();

  before(async () => {
    await convexULTest.setupTest(underlying, underlyingWhale, liquidationPaths);
  });

  describe("--------- Happy path --------------", () => {
    it("Farmer should earn money", async () => {
      await convexULTest.testHappyPath();
    });
  });
});
