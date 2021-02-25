pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategy.sol";

contract SushiStrategyMainnet_UST_WETH is MasterChefStrategy {

  address public ust_weth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x8B00eE8606CC70c2dce68dea0CEfe632CCA0fB7b);
    address ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address sushi = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    MasterChefStrategy.initializeStrategy(
      _storage,
      underlying,
      _vault,
      address(0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd), // master chef contract
      sushi,
      85,  // Pool id
      true, // is LP asset
      false // false = use Sushiswap for liquidating
    );
    // sushi is token0, weth is token1
    uniswapRoutes[ust] = [sushi, weth, ust];
    uniswapRoutes[weth] = [sushi, weth];
  }
}
