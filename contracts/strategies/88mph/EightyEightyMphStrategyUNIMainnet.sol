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
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);

    EightyEightMphStrategy.initializeBaseStrategy(
      _storage,
      _vault,
      underlying,
      rewardPool,
      mph,
      5000 // percentage of rewards after profit fee to distribute as xMPH
    );

    rewardTokens = [crv, cvx];
    storedLiquidationPaths[crv][weth] = [crv, weth];
    storedLiquidationDexes[crv][weth] = [sushiDex];
    storedLiquidationPaths[cvx][weth] = [cvx, weth];
    storedLiquidationDexes[cvx][weth] = [sushiDex];
    storedLiquidationPaths[weth][eurt] = [weth, eurt];
    storedLiquidationDexes[weth][eurt] = [uniV3Dex];
  }
}
