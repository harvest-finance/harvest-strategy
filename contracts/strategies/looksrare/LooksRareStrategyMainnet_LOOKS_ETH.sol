pragma solidity 0.5.16;

import "./LooksRareStrategy.sol";

contract LooksRareStrategyMainnet_LOOKS_ETH is LooksRareStrategy {

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xDC00bA87Cc2D99468f7f34BC04CBf72E111A32f7);
    address rewardPool = address(0x2A70e7F51f6cd40C3E9956aa964137668cBfAdC5);
    address looks = address(0xf4d2888d29D722226FafA5d9B24F9164c092421E);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    bytes32 uniV2Dex = bytes32(0xde2d1a51640f78257713031680d1f306297d957426e912ab21317b9cc9495a41);
    LooksRareStrategy.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool,
      looks
    );
    storedLiquidationPaths[looks][weth] = [looks, weth];
    storedLiquidationDexes[looks][weth] = [uniV2Dex];
  }
}
