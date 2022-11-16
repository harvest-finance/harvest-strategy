pragma solidity 0.5.16;

import "./base/ConvexStrategyUL_V2.sol";

contract ConvexStrategyUSDDMainnet is ConvexStrategyUL_V2 {

  address public usdd_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xe6b5CC1B4b47305c58392CE3D359B10282FC36Ea); // Info -> LP Token address
    address rewardPool = address(0x7D475cc8A5E0416f0e63042547aDB94ca7045A5b); // Info -> Rewards contract address
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address curveDeposit = address(0xA79828DF1850E8a3A3064576f380D90aECDD3359); // only needed if deposits are not via underlying
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);
    ConvexStrategyUL_V2.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, // rewardPool
      96,  // Pool id: Info -> Rewards contract address -> read -> pid
      dai, // depositToken
      1, //depositArrayPosition. Find deposit transaction -> input params
      curveDeposit, // deposit contract: usually underlying. Find deposit transaction -> interacted contract
      4, //nTokens -> total number of deposit tokens
      true, //metaPool -> if LP token address == pool address (at curve)
      500 // hodlRatio 5%
    );
    rewardTokens = [crv, cvx];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[weth][dai] = [weth, dai];
    storedLiquidationDexes[weth][dai] = [uniV3Dex];
  }
}
