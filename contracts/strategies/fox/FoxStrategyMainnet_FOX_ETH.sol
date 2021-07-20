pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardUniLPStrategyWithBuyback.sol";

contract FoxStrategyMainnet_FOX_ETH is SNXRewardUniLPStrategyWithBuyback {

  address public fox_weth = address(0x470e8de2eBaef52014A47Cb5E6aF86884947F08c);
  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public fox = address(0xc770EEfAd204B5180dF6a14Ee197D99d808ee52d);
  address public rewardPoolAddr = address(0xDd80E21669A664Bce83E3AD9a0d74f8Dad5D9E72);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXRewardUniLPStrategyWithBuyback(
    _storage,
    fox_weth,
    _vault,
    rewardPoolAddr,
    fox,
    uniswapRouterAddress,
    _distributionPool,
    10000 //buyback ration, 100%
  )
  public {
    uniswapRoutes[weth] = [fox, weth];
  }
}
