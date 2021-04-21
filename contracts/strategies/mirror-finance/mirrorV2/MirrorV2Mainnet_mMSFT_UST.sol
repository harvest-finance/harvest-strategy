pragma solidity 0.5.16;

import "../../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../../base/snx-base/SNXRewardStrategyWithBuyback.sol";

contract MirrorV2Mainnet_mMSFT_UST is SNXRewardStrategyWithBuyback {

  address public mmsft_ust = address(0xeAfAD3065de347b910bb88f09A5abE580a09D655);
  address public rewardPool = address(0x27a14c03C364D3265e0788f536ad8d7afB0695F7);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);
  address public mmsft = address(0x41BbEDd7286dAab5910a1f15d12CBda839852BD7);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXRewardStrategyWithBuyback(_storage, mmsft_ust, _vault, rewardPool, mir, uniswapRouterAddress, _distributionPool, 5000)
  public {
    require(IVault(_vault).underlying() == mmsft_ust, "Underlying mismatch");
    uniswapRoutes[mmsft] = [mir, ust, mmsft];
    uniswapRoutes[ust] = [mir, ust];
  }
}
