pragma solidity 0.5.16;

import "./UniverseStrategy.sol";

contract UniverseStrategyMainnet_XYZ_USDC is UniverseStrategy {

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xBBBdB106A806173d1eEa1640961533fF3114d69A);
    address xyz = address(0x618679dF9EfCd19694BB1daa8D00718Eacfa2883);
    address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address rewardPool_xyz_usdc = address(0xc825D56a12EeC2A7E6f3a1CCe6675e5d41F3Ec3a);
    address stakingPool = address(0x2d615795a8bdb804541C69798F13331126BA0c09);
    bytes32 sushiDex = 0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a;
    UniverseStrategy.initializeStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool_xyz_usdc,
      xyz,
      stakingPool,
      true // is LP asset
    );
    storedLiquidationPaths[xyz][usdc] = [xyz, usdc];
    storedLiquidationDexes[xyz][usdc] = [sushiDex];
  }
}
