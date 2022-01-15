pragma solidity 0.5.16;

import "./base/ConvexStrategyUL.sol";

contract ConvexStrategyMIM_USTMainnet is ConvexStrategyUL {

  address public mim_ust_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x55A8a39bc9694714E2874c1ce77aa1E599461E18); // Info -> LP Token address
    address rewardPool = address(0xC62DE533ea77D46f3172516aB6b1000dAf577E89); // Info -> Rewards contract address
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address mim = address(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    address curveDeposit = underlying; // only needed if deposits are not via underlying
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    ConvexStrategyUL.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, // rewardPool
      52,  // Pool id: Info -> Rewards contract address -> read -> pid
      mim, // depositToken
      0, //depositArrayPosition. Find deposit transaction -> input params 
      curveDeposit, // deposit contract: usually underlying. Find deposit transaction -> interacted contract 
      2, //nTokens -> total number of deposit tokens
      false, //metaPool -> if LP token address == pool address (at curve)
      1000 // hodlRatio 10%
    );
    rewardTokens = [crv, cvx];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[weth][mim] = [weth, mim];
    storedLiquidationDexes[weth][mim] = [sushiDex];
  }
}
