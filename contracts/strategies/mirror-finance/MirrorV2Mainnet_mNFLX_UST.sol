pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategyWithBuyback.sol";

contract MirrorV2Mainnet_mNFLX_UST is SNXRewardStrategyWithBuyback {

  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);
  address public mnflx_ust = address(0xC99A74145682C4b4A6e9fa55d559eb49A6884F75);
  address public mnflx = address(0xC8d674114bac90148d11D3C1d33C61835a0F9DCD);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public mNFLXUSTRewardPool = address(0x29cF719d134c1C18daB61C2F4c0529C4895eCF44);
  address public constant universalLiquidatorRegistry = address(0x7882172921E99d590E097cD600554339fBDBc480);
  address public constant farm = address(0xa0246c9032bC3A600820415aE600c6388619A14D);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXRewardStrategyWithBuyback(_storage, mnflx_ust, _vault, mNFLXUSTRewardPool, mir, uniswapRouterAddress, farm, _distributionPool, 5000)
  public {
    uniswapRoutes[farm] = [mir, weth, farm];
    uniswapRoutes[mnflx] = [mir, ust, mnflx];
    uniswapRoutes[ust] = [mir, ust];
    require(IVault(_vault).underlying() == mnflx_ust, "Underlying mismatch");

    // adding ability to liquidate reward tokens manually if there is no liquidity
    unsalvagableTokens[mir] = false;
  }
}
