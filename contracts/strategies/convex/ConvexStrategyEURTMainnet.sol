pragma solidity 0.5.16;

import "./base/ConvexStrategyUL.sol";

contract ConvexStrategyEURTMainnet is ConvexStrategyUL {

  address public eurt_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xFD5dB7463a3aB53fD211b4af195c5BCCC1A03890);
    address rewardPool = address(0xD814BFC091111E1417a669672144aFFAA081c3CE);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address eurt = address(0xC581b735A1688071A1746c968e0798D642EDE491);
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);
    ConvexStrategyUL.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      39,  // Pool id
      eurt,
      0, //depositArrayPosition
      underlying,
      2, //nTokens
      false, //metaPool
      1000 // hodlRatio 10%
    );
    rewardTokens = [crv, cvx];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[weth][eurt] = [weth, eurt];
    storedLiquidationDexes[weth][eurt] = [uniV3Dex];
  }
}
