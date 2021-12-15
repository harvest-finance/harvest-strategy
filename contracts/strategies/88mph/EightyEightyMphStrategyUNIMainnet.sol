pragma solidity 0.5.16;

import "./base/EightyEightMphStrategy.sol";

contract EightyEightMphUNIMainnet is EightyEightMphStrategy {

  address public eightyEightyMphUni_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984); // UNI
    address rewardPool = address(0x5dda04b2BDBBc3FcFb9B60cd9eBFd1b27f1A4fE3);
    address mph = address(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);

    EightyEightMphStrategy.initializeBaseStrategy(
      _storage,
      _vault,
      underlying,
      rewardPool,
      address(0), // pot pool -> manually set it later
      500, // percentage of rewards after profit fee to distribute as xMPH,
      180 days // maturation target
    );

    // path 1, used for mph -> rewardToken
    storedLiquidationPaths[mph][weth] = [mph, weth];
    storedLiquidationDexes[mph][weth] = [sushiDex];

    // path 2, used for reward token -> underlying
    storedLiquidationPaths[weth][underlying] = [weth, underlying];
    storedLiquidationDexes[weth][underlying] = [uniV3Dex];

    // path 3, used for underlying -> reward token. This path is used at the rollover
    // when we liquidate the fixed yield earnings to reward token
    storedLiquidationPaths[underlying][weth] = [underlying, weth];
    storedLiquidationDexes[underlying][weth] = [uniV3Dex];
  }
}
