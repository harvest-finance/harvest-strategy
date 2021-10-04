pragma solidity 0.5.16;

import "./base/OneInchStrategy_DAI_X.sol";

/**
* This strategy is for the DAI/LDO LP token on 1inch
*/
contract OneInchStrategy_DAI_LDO is OneInchStrategy_DAI_X {

  address public dai_ldo_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xC1A900Ae76dB21dC5aa8E418Ac0F4E888A4C7431);
    address rewardPool = address(0xd7012cDeBF10d5B352c601563aA3A8D1795A3F52);
    address oneInch = address(0x111111111117dC0aa78b770fA6A738034120C302);
    address ldo = address(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32);
    address stEth = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 oneInchDex = bytes32(0xd9bf0c0ec020d1a26ba6698a24db3a538215d8fbf30588bddde694887c4cb55e);

    OneInchStrategy_DAI_X.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      300  // profit sharing numerator
    );

    rewardTokens = [oneInch, ldo];
    storedLiquidationPaths[oneInch][weth] = [oneInch, weth];
    storedLiquidationDexes[oneInch][weth] = [oneInchDex];
    storedLiquidationPaths[ldo][weth] = [ldo, weth];
    storedLiquidationDexes[ldo][weth] = [sushiDex];
    storedLiquidationPaths[weth][dai] = [weth, dai];
    storedLiquidationDexes[weth][dai] = [sushiDex];
    storedLiquidationPaths[weth][stEth] = [weth, dai, stEth];
    storedLiquidationDexes[weth][stEth] = [sushiDex, oneInchDex];
  }
}
