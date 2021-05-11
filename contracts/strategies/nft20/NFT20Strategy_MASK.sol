pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategyWithBuyback.sol";

contract NFT20Strategy_MASK is MasterChefStrategyWithBuyback {

  address public mask_eth_unused; // just a differentiator for the bytecode
  address public constant maskEthLp = address(0xaa617C8726ADFDe9e7b08746457E6b90ddB21480);
  address public constant masterChef = address(0x193b775aF4BF9E11656cA48724A710359446BF52);
  address public constant muse = address(0xB6Ca7399B4F9CA56FC27cBfF44F4d2e4Eef1fc81);
  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant mask = address(0xc2BdE1A2fA26890c8E6AcB10C91CC6D9c11F4a73);

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault,
    address _distributionPool
  ) public initializer {
    uint256 poolId = 5;
    MasterChefStrategyWithBuyback.initializeBaseStrategy(
      _storage,
      maskEthLp,
      _vault,
      masterChef,
      muse,
      poolId,
      true, // is LP asset
      true, // use Uniswap
      _distributionPool,
      0
    );
    uniswapRoutes[weth] = [muse, weth]; // swaps to weth
    uniswapRoutes[mask] = [muse, weth, mask]; // no swapping needed
    setSell(true);
  }
}
