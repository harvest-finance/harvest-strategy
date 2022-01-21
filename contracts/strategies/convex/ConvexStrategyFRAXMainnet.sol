pragma solidity 0.5.16;

import "./base/ConvexStrategyUL.sol";

contract ConvexStrategyFRAXMainnet is ConvexStrategyUL {

  address public frax_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B); // Info -> LP Token address
    address rewardPool = address(0xB900EF131301B307dB5eFcbed9DBb50A3e209B2e); // Info -> Rewards contract address
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address frax = address(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    address fxs = address(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
    address fraxCurveDeposit = address(0xA79828DF1850E8a3A3064576f380D90aECDD3359); // only needed if deposits are not via underlying
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniDex = 0xde2d1a51640f78257713031680d1f306297d957426e912ab21317b9cc9495a41;
    ConvexStrategyUL.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, // rewardPool
      32,  // Pool id: Info -> Rewards contract address -> read -> pid
      dai, // depositToken
      1, //depositArrayPosition. Find deposit transaction -> input params 
      fraxCurveDeposit, // deposit contract: usually underlying. Find deposit transaction -> interacted contract 
      4, //nTokens -> total number of deposit tokens
      true, //metaPool -> if LP token address == pool address (at curve)
      1000 // hodlRatio 10%
    );
    rewardTokens = [crv, cvx, fxs];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[fxs][weth] = [fxs, frax, weth];
    storedLiquidationDexes[fxs][weth] = [uniDex, sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[weth][dai] = [weth, dai];
    storedLiquidationDexes[weth][dai] = [sushiDex];
  }
}
