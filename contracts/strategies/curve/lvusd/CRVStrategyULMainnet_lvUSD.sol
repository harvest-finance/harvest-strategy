pragma solidity 0.5.16;

import "./CRVStrategyUL.sol";

contract CRVStrategyULMainnet_lvUSD is CRVStrategyUL {

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xe9123CBC5d1EA65301D417193c40A72Ac8D53501);
    address gauge = address(0xf2cBa59952cc09EB23d6F7baa2C47aB79B9F2945);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address arch = address(0x73C69d24ad28e2d43D03CBf35F79fE26EBDE1011);
    address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address curveDeposit = address(0xA79828DF1850E8a3A3064576f380D90aECDD3359);
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);
    bytes32 uniV2Dex = bytes32(0xde2d1a51640f78257713031680d1f306297d957426e912ab21317b9cc9495a41);
    CRVStrategyUL.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      gauge, // rewardPool
      usdc, // depositToken
      2, //depositArrayPosition. Find deposit transaction -> input params
      curveDeposit, // deposit contract: usually underlying. Find deposit transaction -> interacted contract
      500 // hodlRatio 5%
    );
    rewardTokens = [crv, arch];
    storedLiquidationPaths[crv][usdc] = [crv, weth, usdc];
    storedLiquidationDexes[crv][usdc] = [sushiDex, uniV3Dex];
    storedLiquidationPaths[arch][usdc] = [arch, usdc];
    storedLiquidationDexes[arch][usdc] = [uniV2Dex];
  }
}