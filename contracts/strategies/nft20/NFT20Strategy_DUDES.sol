pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategyWithBuyback.sol";

contract NFT20Strategy_DUDES is MasterChefStrategyWithBuyback {

  address public dudes_eth_unused; // just a differentiator for the bytecode
  address public constant dudesEthLp = address(0x04914cb01eeC94E320e3A88b3c7A7e9B1609d13C);
  address public constant masterChef = address(0x193b775aF4BF9E11656cA48724A710359446BF52);
  address public constant muse = address(0xB6Ca7399B4F9CA56FC27cBfF44F4d2e4Eef1fc81);
  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant dude = address(0x2313E39841fb3809dA0Ff6249c2067ca84795846);

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault,
    address _distributionPool
  ) public initializer {
    uint256 poolId = 6;
    MasterChefStrategyWithBuyback.initializeBaseStrategy(
      _storage,
      dudesEthLp,
      _vault,
      masterChef,
      muse,
      poolId,
      true, // is LP asset
      true, // use Uniswap
      _distributionPool,
      5000
    );
    uniswapRoutes[weth] = [muse, weth]; // swaps to weth
    uniswapRoutes[dude] = [muse, weth, dude];
    setSell(true);
  }
}
