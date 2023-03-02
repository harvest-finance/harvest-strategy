pragma solidity 0.5.16;

import "./base/ConvexStrategyUL_V2.sol";

contract ConvexStrategyPBTCMainnet is ConvexStrategyUL_V2 {

  address public pbtc_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xC9467E453620f16b57a34a770C6bceBECe002587); // Info -> LP Token address
    address rewardPool = address(0x589761B61D8d1C8ecc36F3cFE35932670749015a); // Info -> Rewards contract address
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address pnt = address(0x89Ab32156e46F46D02ade3FEcbe5Fc4243B9AAeD);
    address wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address curveDeposit = address(0x7AbDBAf29929e7F8621B757D2a7c04d78d633834); // only needed if deposits are not via underlying
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniV2Dex = bytes32(0xde2d1a51640f78257713031680d1f306297d957426e912ab21317b9cc9495a41);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);
    ConvexStrategyUL_V2.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, // rewardPool
      77,  // Pool id: Info -> Rewards contract address -> read -> pid
      wbtc, // depositToken
      2, //depositArrayPosition. Find deposit transaction -> input params
      curveDeposit, // deposit contract: usually underlying. Find deposit transaction -> interacted contract
      4, //nTokens -> total number of deposit tokens
      true, //metaPool -> if LP token address == pool address (at curve)
      500 // hodlRatio 5%
    );
    rewardTokens = [crv, cvx, pnt];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[pnt][weth] = [pnt, weth];
    storedLiquidationDexes[pnt][weth] = [uniV2Dex];
    storedLiquidationPaths[weth][wbtc] = [weth, wbtc];
    storedLiquidationDexes[weth][wbtc] = [uniV3Dex];
  }
}
