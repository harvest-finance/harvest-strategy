pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategy.sol";

contract NarwhaleStrategyMainnet_BAC is MasterChefStrategy {

  address public bac_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address nawa = address(0x7D529a5b3c41126760A0fA3c1a9652d8A7A07793);
    address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address bac = address(0x3449FC1Cd036255BA1EB19d65fF4BA2b8903A69a);
    MasterChefStrategy.initializeStrategy(
      _storage,
      bac,
      _vault,
      address(0xbF528830d505FA8C6Ee2A3C0De92797D278C5478), // reward pool
      nawa,
      8, // Pool id
      false, // is LP asset
      true // use Uniswap
    );
    uniswapRoutes[bac] = [nawa, usdc, dai, bac];
  }
}
