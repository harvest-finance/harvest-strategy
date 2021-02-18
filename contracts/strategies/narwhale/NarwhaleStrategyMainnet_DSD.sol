pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategy.sol";

contract NarwhaleStrategyMainnet_DSD is MasterChefStrategy {

  address public dsd_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address nawa = address(0x7D529a5b3c41126760A0fA3c1a9652d8A7A07793);
    address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address dsd = address(0xBD2F0Cd039E0BFcf88901C98c0bFAc5ab27566e3);
    MasterChefStrategy.initializeStrategy(
      _storage,
      dsd,
      _vault,
      address(0xbF528830d505FA8C6Ee2A3C0De92797D278C5478), // reward pool
      nawa,
      4, // Pool id
      false, // is LP asset
      true // use Uniswap
    );
    uniswapRoutes[dsd] = [nawa, usdc, dsd];
  }
}
