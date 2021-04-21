pragma solidity 0.5.16;

import "../../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../../base/snx-base/SNXRewardStrategyWithBuyback.sol";

contract MirrorV2Mainnet_mSLV_UST is SNXRewardStrategyWithBuyback {

  address public mslv_ust = address(0x860425bE6ad1345DC7a3e287faCBF32B18bc4fAe);
  address public rewardPool = address(0xDB278fb5f7d4A7C3b83F80D18198d872Bbf7b923);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);
  address public mslv = address(0x9d1555d8cB3C846Bb4f7D5B1B1080872c3166676);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXRewardStrategyWithBuyback(_storage, mslv_ust, _vault, rewardPool, mir, uniswapRouterAddress, _distributionPool, 5000)
  public {
    require(IVault(_vault).underlying() == mslv_ust, "Underlying mismatch");
    uniswapRoutes[mslv] = [mir, ust, mslv];
    uniswapRoutes[ust] = [mir, ust];
  }
}
