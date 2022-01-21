pragma solidity 0.5.16;

import "./base/ConvexStrategyUL.sol";

contract ConvexStrategy3EURMainnet is ConvexStrategyUL {

  address public threeeur_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xb9446c4Ef5EBE66268dA6700D26f96273DE3d571); // Info -> LP Token address
    address rewardPool = address(0x4a9b7eDD67f58654a2c33B587f98c5709AC7d482); // Info -> Rewards contract address
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address eurt = address(0xC581b735A1688071A1746c968e0798D642EDE491);
    address angle = address(0x31429d1856aD1377A8A0079410B297e1a9e214c2);
    address curveDeposit = underlying; // only needed if deposits are not via underlying
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);
    ConvexStrategyUL.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, // rewardPool
      60,  // Pool id: Info -> Rewards contract address -> read -> pid
      eurt, // depositToken
      1, //depositArrayPosition. Find deposit transaction -> input params 
      curveDeposit, // deposit contract: usually underlying. Find deposit transaction -> interacted contract 
      3, //nTokens -> total number of deposit tokens
      false, //metaPool -> if LP token address == pool address (at curve)
      1000 // hodlRatio 10%
    );
    rewardTokens = [crv, cvx, angle];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[angle][weth] = [angle, weth];
    storedLiquidationDexes[angle][weth] = [sushiDex];
    storedLiquidationPaths[weth][eurt] = [weth, eurt];
    storedLiquidationDexes[weth][eurt] = [uniV3Dex];
  }
}
