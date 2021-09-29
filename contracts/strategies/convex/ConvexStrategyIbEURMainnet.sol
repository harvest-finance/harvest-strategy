pragma solidity 0.5.16;

import "./base/ConvexStrategyUL.sol";

contract ConvexStrategyIbEURMainnet is ConvexStrategyUL {

  address public ibeur_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x19b080FE1ffA0553469D20Ca36219F17Fcf03859);
    address rewardPool = address(0xCd0559ADb6fAa2fc83aB21Cf4497c3b9b45bB29f);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address ibeur = address(0x96E61422b6A9bA0e068B6c5ADd4fFaBC6a4aae27);
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    ConvexStrategyUL.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      45,  // Pool id
      ibeur,
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
    storedLiquidationPaths[weth][ibeur] = [weth, ibeur];
    storedLiquidationDexes[weth][ibeur] = [sushiDex];
  }
}
