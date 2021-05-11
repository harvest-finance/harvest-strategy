pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategyWithBuyback.sol";

contract NFT20Strategy_MCAT is MasterChefStrategyWithBuyback {

  address public mcat_eth_unused; // just a differentiator for the bytecode
  address public constant mcatEthLp = address(0x31C507636a4cAB752A8A069B865099924BD5F1a9);
  address public constant masterChef = address(0x193b775aF4BF9E11656cA48724A710359446BF52);
  address public constant muse = address(0xB6Ca7399B4F9CA56FC27cBfF44F4d2e4Eef1fc81);
  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant mcat = address(0xf961A1Fa7C781Ecd23689fE1d0B7f3B6cBB2f972);

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault,
    address _distributionPool
  ) public initializer {
    uint256 poolId = 9;
    MasterChefStrategyWithBuyback.initializeBaseStrategy(
      _storage,
      mcatEthLp,
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
    uniswapRoutes[mcat] = [muse, weth, mcat];
    setSell(true);
  }
}
