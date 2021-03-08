pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategy.sol";

contract BDPStrategyMainnet_WETH is MasterChefStrategy {

  address public weth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address bdp = address(0xf3dcbc6D72a4E1892f7917b7C43b74131Df8480e);
    MasterChefStrategy.initializeStrategy(
      _storage,
      underlying,
      _vault,
      address(0x0De845955E2bF089012F682fE9bC81dD5f11B372), // master chef contract
      bdp,
      1,  // Pool id
      false, // is LP asset
      true // false = use Sushiswap for liquidating
    );
    // sushi is token0, weth is token1
    uniswapRoutes[underlying] = [bdp, underlying];
  }
}
