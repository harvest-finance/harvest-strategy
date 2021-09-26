pragma solidity 0.5.16;

import "./base/ConvexStrategyUL.sol";

contract ConvexStrategycvxCRVMainnet is ConvexStrategyUL {

  address public cvxCRV_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x9D0464996170c6B9e75eED71c68B99dDEDf279e8);
    address rewardPool = address(0x0392321e86F42C2F94FBb0c6853052487db521F0);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    ConvexStrategyUL.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      41,  // Pool id
      crv,
      0, //depositArrayPosition
      underlying,
      2, //nTokens
      false, //metaPool
      1000 // hodlRatio 10%
    );
    rewardTokens = [crv, cvx];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[weth][crv] = [weth, crv];
    storedLiquidationDexes[weth][crv] = [sushiDex];
  }
}
