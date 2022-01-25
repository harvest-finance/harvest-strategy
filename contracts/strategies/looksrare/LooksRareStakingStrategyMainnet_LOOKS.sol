pragma solidity 0.5.16;

import "./LooksRareStakingStrategy.sol";

contract LooksRareStakingStrategyMainnet_LOOKS is LooksRareStakingStrategy {

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address looks = address(0xf4d2888d29D722226FafA5d9B24F9164c092421E); // underlying = LOOKS
    address rewardPool = address(0xBcD7254A1D759EFA08eC7c3291B2E85c5dCC12ce);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    bytes32 uniV2Dex = bytes32(0xde2d1a51640f78257713031680d1f306297d957426e912ab21317b9cc9495a41);
    
    LooksRareStakingStrategy.initializeBaseStrategy(
      _storage,
      looks, // underlying
      _vault,
      rewardPool,
      weth // rewardToken
    );
    storedLiquidationPaths[weth][looks] = [weth, looks];
    storedLiquidationDexes[weth][looks] = [uniV2Dex];
  }
}
