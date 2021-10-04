pragma solidity 0.5.16;

import "./base/ConvexStrategyUL.sol";

contract ConvexStrategyUSDPMainnet is ConvexStrategyUL {

  address public usdp_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x7Eb40E450b9655f4B3cC4259BCC731c63ff55ae6);
    address rewardPool = address(0x24DfFd1949F888F91A0c8341Fc98a3F280a782a8);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address duck = address(0x92E187a03B6CD19CB6AF293ba17F2745Fd2357D5);
    address usdpCurveDeposit = address(0x3c8cAee4E09296800f8D29A68Fa3837e2dae4940);
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);
    ConvexStrategyUL.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      28,  // Pool id
      dai,
      1, //depositArrayPosition
      usdpCurveDeposit,
      4, //nTokens
      false, //metaPool
      1000 // hodlRatio 10%
    );

    rewardTokens = [crv, cvx, duck];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[duck][weth] = [duck, weth];
    storedLiquidationDexes[duck][weth] = [uniV3Dex];
    storedLiquidationPaths[weth][dai] = [weth, dai];
    storedLiquidationDexes[weth][dai] = [sushiDex];
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
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address duck = address(0x92E187a03B6CD19CB6AF293ba17F2745Fd2357D5);
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);

    rewardTokens = [crv, cvx, duck];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[duck][weth] = [duck, weth];
    storedLiquidationDexes[duck][weth] = [uniV3Dex];
    storedLiquidationPaths[weth][dai] = [weth, dai];
    storedLiquidationDexes[weth][dai] = [sushiDex];
  }
}
