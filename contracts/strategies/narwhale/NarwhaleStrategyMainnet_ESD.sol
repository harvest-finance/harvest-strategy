pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategy.sol";

contract NarwhaleStrategyMainnet_ESD is MasterChefStrategy {

  address public esd_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address nawa = address(0x7D529a5b3c41126760A0fA3c1a9652d8A7A07793);
    address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address esd = address(0x36F3FD68E7325a35EB768F1AedaAe9EA0689d723);
    MasterChefStrategy.initializeStrategy(
      _storage,
      esd,
      _vault,
      address(0xbF528830d505FA8C6Ee2A3C0De92797D278C5478), // reward pool
      nawa,
      5, // Pool id
      false, // is LP asset
      true // use Uniswap
    );
    uniswapRoutes[esd] = [nawa, usdc, esd];
  }
}
