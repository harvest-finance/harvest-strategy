pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategyWithBuyback.sol";

contract NFT20Strategy_MEME is MasterChefStrategyWithBuyback {

  address public meme_eth_unused; // just a differentiator for the bytecode
  address public constant memeEthLp = address(0xE14f1283059afA8d3c9c52EFF76FE91854F5D1B3);
  address public constant masterChef = address(0x193b775aF4BF9E11656cA48724A710359446BF52);
  address public constant muse = address(0xB6Ca7399B4F9CA56FC27cBfF44F4d2e4Eef1fc81);
  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant meme = address(0x60ACD58d00b2BcC9a8924fdaa54A2F7C0793B3b2);

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault,
    address _distributionPool
  ) public initializer {
    uint256 poolId = 4;
    MasterChefStrategyWithBuyback.initializeBaseStrategy(
      _storage,
      memeEthLp,
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
    uniswapRoutes[meme] = [muse, weth, meme];
    setSell(true);
  }
}
