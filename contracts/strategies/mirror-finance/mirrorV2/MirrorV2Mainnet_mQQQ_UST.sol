pragma solidity 0.5.16;

import "../../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../../base/snx-base/SNXRewardStrategyWithBuyback.sol";

contract MirrorV2Mainnet_mQQQ_UST is SNXRewardStrategyWithBuyback {

  address public mqqq_ust = address(0x9E3B47B861B451879d43BBA404c35bdFb99F0a6c);
  address public rewardPool = address(0xc1d2ca26A59E201814bF6aF633C3b3478180E91F);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);
  address public mqqq = address(0x13B02c8dE71680e71F0820c996E4bE43c2F57d15);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXRewardStrategyWithBuyback(_storage, mqqq_ust, _vault, rewardPool, mir, uniswapRouterAddress, _distributionPool, 5000)
  public {
    require(IVault(_vault).underlying() == mqqq_ust, "Underlying mismatch");
    uniswapRoutes[mqqq] = [mir, ust, mqqq];
    uniswapRoutes[ust] = [mir, ust];
  }
}
