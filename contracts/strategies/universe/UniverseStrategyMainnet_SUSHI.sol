pragma solidity 0.5.16;

import "./UniverseStrategy.sol";

contract UniverseStrategyMainnet_SUSHI is UniverseStrategy {

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    address xyz = address(0x618679dF9EfCd19694BB1daa8D00718Eacfa2883);
    address rewardPool_sushi = address(0xe3e1860a5653c030818226e0cB1efb4a477A5F32);
    address stakingPool = address(0x2d615795a8bdb804541C69798F13331126BA0c09);
    bytes32 sushiDex = 0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a;
    UniverseStrategy.initializeStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool_sushi,
      xyz,
      stakingPool,
      false // is LP asset
    );
    storedLiquidationPaths[xyz][underlying] = [xyz, underlying];
    storedLiquidationDexes[xyz][underlying] = [sushiDex];
  }
}
