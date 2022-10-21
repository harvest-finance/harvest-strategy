pragma solidity 0.5.16;

import "./base/ConvexStrategyUL_V2.sol";

contract ConvexStrategyTBTC2Mainnet is ConvexStrategyUL_V2 {

  address public tbtc2_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xfa65aa60a9D45623c57D383fb4cf8Fb8b854cC4D); // Info -> LP Token address
    address rewardPool = address(0x455AC43CcE0E17774C0bF240ba709DD5822102f3); // Info -> Rewards contract address
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address curveDeposit = address(0x7AbDBAf29929e7F8621B757D2a7c04d78d633834); // only needed if deposits are not via underlying
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);
    ConvexStrategyUL_V2.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, // rewardPool
      111,  // Pool id: Info -> Rewards contract address -> read -> pid
      wbtc, // depositToken
      2, //depositArrayPosition. Find deposit transaction -> input params
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
    storedLiquidationPaths[weth][wbtc] = [weth, wbtc];
    storedLiquidationDexes[weth][wbtc] = [uniV3Dex];
  }
}
