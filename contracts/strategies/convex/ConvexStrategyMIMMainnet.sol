pragma solidity 0.5.16;

import "./base/ConvexStrategyUL.sol";

contract ConvexStrategyMIMMainnet is ConvexStrategyUL {

  address public mim_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
    address rewardPool = address(0xFd5AbF66b003881b88567EB9Ed9c651F14Dc4771);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address spell = address(0x090185f2135308BaD17527004364eBcC2D37e5F6);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address metaCurveDeposit = address(0xA79828DF1850E8a3A3064576f380D90aECDD3359);
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    ConvexStrategyUL.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      40,  // Pool id
      dai,
      1, //depositArrayPosition
      metaCurveDeposit,
      4, //nTokens
      true, //metaPool
      1000 // hodlRatio 10%
    );
    rewardTokens = [crv, cvx, spell];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[spell][weth] = [spell, weth];
    storedLiquidationDexes[spell][weth] = [sushiDex];
    storedLiquidationPaths[weth][dai] = [weth, dai];
    storedLiquidationDexes[weth][dai] = [sushiDex];
  }
}
