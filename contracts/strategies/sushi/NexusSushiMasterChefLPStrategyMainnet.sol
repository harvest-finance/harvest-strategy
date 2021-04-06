pragma solidity 0.5.16;

import "./NexusSushiMasterChefLPStrategy.sol";

contract NexusSushiMasterChefLPStrategyMainnet is NexusSushiMasterChefLPStrategy {

  address public sushi_weth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault,
    address _nexusSushi,
    address _orbsInsurance,
    uint _nexusTmp // TODO remove unused
  ) public initializer {
    address underlying = _nexusSushi;
    NexusSushiMasterChefLPStrategy.initializeStrategy(
      _storage,
      underlying,
      _vault,
      address(0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd), // master chef contract TODO remove
      sushi,
      12,  // Pool id TODO remove
      _nexusSushi, // sushiSingleEth
      _orbsInsurance
    );
    // sushi is token0, weth is token1
    uniswapRoutes[sushi] = [sushi];
    uniswapRoutes[weth] = [sushi, weth];
  }
}
