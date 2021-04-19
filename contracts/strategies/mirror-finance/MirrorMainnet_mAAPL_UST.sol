pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategyWithBuyback.sol";

contract MirrorMainnet_mAAPL_UST is SNXRewardStrategyWithBuyback {

  address public mAAPL_USTu = address(0xB022e08aDc8bA2dE6bA4fECb59C6D502f66e953B);
  address public rewardPool = address(0x735659C8576d88A2Eb5C810415Ea51cB06931696);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public farm = address(0xa0246c9032bC3A600820415aE600c6388619A14D);
  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);
  address public mapple = address(0xd36932143F6eBDEDD872D5Fb0651f4B72Fd15a84);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool,
    address _distributionSwitcher
  )
  SNXRewardStrategyWithBuyback(_storage, mAAPL_USTu, _vault, rewardPool, mir, uniswapRouterAddress, farm, _distributionPool, _distributionSwitcher, 5000)
  public {
    require(IVault(_vault).underlying() == mAAPL_USTu, "Underlying mismatch");
    uniswapRoutes[farm] = [mir, weth, farm];
    uniswapRoutes[mapple] = [mir, ust, mapple];
    uniswapRoutes[ust] = [mir, ust];

    // adding ability to liquidate reward tokens manually if there is no liquidity
    unsalvagableTokens[mir] = false;
  }
}
