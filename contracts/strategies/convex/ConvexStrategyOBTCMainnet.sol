pragma solidity 0.5.16;

import "./base/ConvexStrategyUL.sol";

contract ConvexStrategyOBTCMainnet is ConvexStrategyUL {

  address public obtc_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x2fE94ea3d5d4a175184081439753DE15AeF9d614);
    address rewardPool = address(0xeeeCE77e0bc5e59c77fc408789A9A172A504bD2f);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address bor = address(0xBC19712FEB3a26080eBf6f2F7849b417FdD792CA);
    address wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address obtcCurveDeposit = address(0xd5BCf53e2C81e1991570f33Fa881c49EEa570C8D);
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);
    ConvexStrategyUL.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      20,  // Pool id
      wbtc,
      2, //depositArrayPosition
      obtcCurveDeposit,
      4, //nTokens
      false, //metaPool
      1000 // hodlRatio 10%
    );
    rewardTokens = [crv, cvx, bor];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[bor][weth] = [bor, weth];
    storedLiquidationDexes[bor][weth] = [uniV3Dex];
    storedLiquidationPaths[weth][wbtc] = [weth, wbtc];
    storedLiquidationDexes[weth][wbtc] = [sushiDex];
  }

  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
    setHodlVault(multiSigAddr);
    setHodlRatio(1000); // 10%
    _setNTokens(4);
    _setUniversalLiquidatorRegistry(address(0x7882172921E99d590E097cD600554339fBDBc480));
    _setUniversalLiquidator(ILiquidatorRegistry(universalLiquidatorRegistry()).universalLiquidator());

    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address bor = address(0xBC19712FEB3a26080eBf6f2F7849b417FdD792CA);
    address wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);
    rewardTokens = [crv, cvx, bor];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[bor][weth] = [bor, weth];
    storedLiquidationDexes[bor][weth] = [uniV3Dex];
    storedLiquidationPaths[weth][wbtc] = [weth, wbtc];
    storedLiquidationDexes[weth][wbtc] = [sushiDex];
  }
}
