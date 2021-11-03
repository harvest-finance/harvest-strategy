pragma solidity 0.5.16;

import "./base/ConvexStrategyUL.sol";

contract ConvexStrategyMUSDMainnet is ConvexStrategyUL {

  address public musd_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x1AEf73d49Dedc4b1778d0706583995958Dc862e6);
    address rewardPool = address(0xDBFa6187C79f4fE4Cda20609E75760C5AaE88e52);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address mta = address(0xa3BeD4E1c75D00fa6f4E5E6922DB7261B5E9AcD2);
    address musdCurveDeposit = address(0x803A2B40c5a9BB2B86DD630B274Fa2A9202874C2);
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);
    ConvexStrategyUL.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      14,  // Pool id
      dai,
      1, //depositArrayPosition
      musdCurveDeposit,
      4, //nTokens
      false, //metaPool
      1000 // hodlRatio 10%
    );

    rewardTokens = [crv, cvx, mta];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[mta][weth] = [mta, dai, weth];
    storedLiquidationDexes[mta][weth] = [uniV3Dex, sushiDex];
    storedLiquidationPaths[weth][dai] = [weth, dai];
    storedLiquidationDexes[weth][dai] = [sushiDex];
  }
}
