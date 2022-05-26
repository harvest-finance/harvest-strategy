pragma solidity 0.5.16;

import "./base/ConvexStrategyCvxCRV.sol";

contract ConvexStrategyCvxCRVMainnet_cvxCRV is ConvexStrategyCvxCRV {

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7); // Info -> LP Token address
    address rewardPool = address(0x3Fe65692bfCD0e6CF84cB1E7d24108E434A7587e); // Info -> Rewards contract address
    address crvDeposit = address(0x8014595F2AB54cD7c604B00E9fb932176fDc86Ae);
    address cvxCrvSwap = address(0x9D0464996170c6B9e75eED71c68B99dDEDf279e8);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    ConvexStrategyCvxCRV.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool,
      crvDeposit,
      cvxCrvSwap,
      1000 // hodlRatio 10%
    );
    rewardTokens = [crv, cvx, threeCrvToken];
    storedLiquidationPaths[cvx][crv] = [cvx, crv];
    storedLiquidationDexes[cvx][crv] = [sushiDex];
    storedLiquidationPaths[dai][crv] = [dai, crv];
    storedLiquidationDexes[dai][crv] = [sushiDex];
  }
}
