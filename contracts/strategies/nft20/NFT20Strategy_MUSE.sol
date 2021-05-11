pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategyWithBuyback.sol";

contract NFT20Strategy_MUSE is MasterChefStrategyWithBuyback {

  address public muse_eth_unused; // just a differentiator for the bytecode
  address public constant museEthLp = address(0x20d2C17d1928EF4290BF17F922a10eAa2770BF43);
  address public constant masterChef = address(0x193b775aF4BF9E11656cA48724A710359446BF52);
  address public constant muse = address(0xB6Ca7399B4F9CA56FC27cBfF44F4d2e4Eef1fc81);
  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault,
    address _distributionPool
  ) public initializer {
    uint256 poolId = 0;
    MasterChefStrategyWithBuyback.initializeBaseStrategy(
      _storage,
      museEthLp,
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
    uniswapRoutes[muse] = [muse]; // no swapping needed
    setSell(true);
  }
}
