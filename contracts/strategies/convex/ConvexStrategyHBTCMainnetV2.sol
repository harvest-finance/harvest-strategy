pragma solidity 0.5.16;

import "./base/ConvexStrategyUL_V2.sol";

contract ConvexStrategyHBTCMainnetV2 is ConvexStrategyUL_V2 {

  address public hbtc_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xb19059ebb43466C323583928285a49f558E572Fd); // Info -> LP Token address
    address rewardPool = address(0x618BD6cBA676a46958c63700C04318c84a7b7c0A); // Info -> Rewards contract address
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address curveDeposit = address(0x4CA9b3063Ec5866A4B82E437059D2C43d1be596F); // only needed if deposits are not via underlying
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);
    ConvexStrategyUL_V2.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, // rewardPool
      8,  // Pool id: Info -> Rewards contract address -> read -> pid
      wbtc, // depositToken
      1, //depositArrayPosition. Find deposit transaction -> input params
      curveDeposit, // deposit contract: usually underlying. Find deposit transaction -> interacted contract
      2, //nTokens -> total number of deposit tokens
      false, //metaPool -> if LP token address == pool address (at curve)
      500 // hodlRatio 5%
    );
    rewardTokens = [crv, cvx];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[weth][wbtc] = [weth, wbtc];
    storedLiquidationDexes[weth][wbtc] = [uniV3Dex];
  }
}
