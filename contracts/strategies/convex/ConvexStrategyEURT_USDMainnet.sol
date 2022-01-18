pragma solidity 0.5.16;

import "./base/ConvexStrategyUL.sol";

contract ConvexStrategyEURT_USDMainnet is ConvexStrategyUL {

  address public eurs_usd_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x3b6831c0077a1e44ED0a21841C3bC4dC11bCE833); // Info -> LP Token address
    address rewardPool = address(0xD2B756Af4E345A8657C0656C148aDCD3000C97A4); // Info -> Rewards contract address
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address curveDeposit = address(0x5D0F47B32fDd343BfA74cE221808e2abE4A53827); // only needed if deposits are not via underlying
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    ConvexStrategyUL.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, // rewardPool
      55,  // Pool id: Info -> Rewards contract address -> read -> pid
      dai, // depositToken
      1, //depositArrayPosition. Find deposit transaction -> input params 
      curveDeposit, // deposit contract: usually underlying. Find deposit transaction -> interacted contract 
      4, //nTokens -> total number of deposit tokens
      false, //metaPool -> if LP token address == pool address (at curve)
      1000 // hodlRatio 10%
    );
    rewardTokens = [crv, cvx];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[weth][dai] = [weth, dai];
    storedLiquidationDexes[weth][dai] = [sushiDex];
  }
}
