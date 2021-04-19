pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategyWithBuyback.sol";

contract MirrorMainnet_MIR_UST is SNXRewardStrategyWithBuyback {

  address public mir_ust = address(0x87dA823B6fC8EB8575a235A824690fda94674c88);
  address public rewardPool = address(0x5d447Fc0F8965cED158BAB42414Af10139Edf0AF);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public farm = address(0xa0246c9032bC3A600820415aE600c6388619A14D);
  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXRewardStrategyWithBuyback(_storage, mir_ust, _vault, rewardPool, mir, uniswapRouterAddress, farm, _distributionPool, 5000)
  public {
    require(IVault(_vault).underlying() == mir_ust, "Underlying mismatch");
    uniswapRoutes[farm] = [mir, weth, farm];
    uniswapRoutes[ust] = [mir, ust];

    // adding ability to liquidate reward tokens manually if there is no liquidity
    unsalvagableTokens[mir] = false;
  }
}
