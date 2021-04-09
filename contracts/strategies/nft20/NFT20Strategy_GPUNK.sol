pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategyWithBuyback.sol";

contract NFT20Strategy_GPUNK is MasterChefStrategyWithBuyback {

  address public gpunk_eth_unused; // just a differentiator for the bytecode
  address public constant gpunkEthLp = address(0xBb1565072FB4f3244eBcE5Bc8Dfeda6baEb78Ad3);
  address public constant masterChef = address(0x193b775aF4BF9E11656cA48724A710359446BF52);
  address public constant muse = address(0xB6Ca7399B4F9CA56FC27cBfF44F4d2e4Eef1fc81);
  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant gpunk = address(0xcCcBF11AC3030ee8CD7a04CFE15a3718df6dD030);

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault,
    address _distributionPool
  ) public initializer {
    uint256 poolId = 8;
    MasterChefStrategyWithBuyback.initializeBaseStrategy(
      _storage,
      gpunkEthLp,
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
    uniswapRoutes[gpunk] = [muse, weth, gpunk];
    setSell(true);
  }
}
