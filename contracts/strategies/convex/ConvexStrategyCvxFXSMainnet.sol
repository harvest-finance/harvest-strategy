pragma solidity 0.5.16;

import "./base/ConvexStrategyUL_V2.sol";

contract ConvexStrategyCvxFXSMainnet is ConvexStrategyUL_V2 {

  address public cvxfxs_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xF3A43307DcAFa93275993862Aae628fCB50dC768); // Info -> LP Token address
    address rewardPool = address(0xf27AFAD0142393e4b3E5510aBc5fe3743Ad669Cb); // Info -> Rewards contract address
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address fxs = address(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
    address curveDeposit = address(0xd658A338613198204DCa1143Ac3F01A722b5d94A);
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    ConvexStrategyUL_V2.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, // rewardPool
      72,  // Pool id: Info -> Rewards contract address -> read -> pid
      fxs, // depositToken
      0, //depositArrayPosition. Find deposit transaction -> input params
      curveDeposit, // deposit contract: usually underlying. Find deposit transaction -> interacted contract
      2, //nTokens -> total number of deposit tokens
      false, //metaPool -> if LP token address == pool address (at curve)
      500 // hodlRatio 5%
    );
    rewardTokens = [crv, cvx, fxs];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[fxs][weth] = [fxs, weth];
    storedLiquidationDexes[fxs][weth] = [sushiDex];
    storedLiquidationPaths[weth][fxs] = [weth, fxs];
    storedLiquidationDexes[weth][fxs] = [sushiDex];
  }
}
