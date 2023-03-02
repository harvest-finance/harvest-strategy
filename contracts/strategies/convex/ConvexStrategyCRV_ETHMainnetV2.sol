pragma solidity 0.5.16;

import "./base/ConvexStrategyUL_V2.sol";

contract ConvexStrategyCRV_ETHMainnetV2 is ConvexStrategyUL_V2 {

  address public crv_eth_v2_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xEd4064f376cB8d68F770FB1Ff088a3d0F3FF5c4d); // Info -> LP Token address
    address rewardPool = address(0x085A2054c51eA5c91dbF7f90d65e728c0f2A270f); // Info -> Rewards contract address
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address curveDeposit = address(0x8301AE4fc9c624d1D396cbDAa1ed877821D7C511); // only needed if deposits are not via underlying
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    ConvexStrategyUL_V2.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, // rewardPool
      61,  // Pool id: Info -> Rewards contract address -> read -> pid
      crv, // depositToken
      1, //depositArrayPosition. Find deposit transaction -> input params
      curveDeposit, // deposit contract: usually underlying. Find deposit transaction -> interacted contract
      2, //nTokens -> total number of deposit tokens
      false, //metaPool -> if LP token address == pool address (at curve)
      500 // hodlRatio 5%
    );

    _setRewardToken(crv);

    rewardTokens = [crv, cvx];
    storedLiquidationPaths[cvx][crv] = [cvx, crv];
    storedLiquidationDexes[cvx][crv] = [sushiDex];
  }
}
