const { ConvexULTest } = require("./util/convex-ul-test.js");

const crv = "0xD533a949740bb3306d119CC777fa900bA034cd52";
const cvx = "0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B";
const weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

//This test was developed at blockNumber 15983140
const strategyArtifact = artifacts.require("ConvexStrategyDOLA_FRAXBPMainnet");

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Mainnet Convex DOLA-FRAXBP", function() {
  // test setup
  const underlying = "0xE57180685E3348589E9521aa53Af0BCD497E884d";
  const underlyingWhale = "0x5EB3C9a23CC030FD2942089da07aD175B9DAD7dc";
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
