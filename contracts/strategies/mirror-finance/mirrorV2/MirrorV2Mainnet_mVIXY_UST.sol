pragma solidity 0.5.16;

import "../../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../../base/snx-base/SNXRewardStrategyWithBuyback.sol";

contract MirrorV2Mainnet_mVIXY_UST is SNXRewardStrategyWithBuyback {

  address public mvixy_ust = address(0x6094367ea57ff4f545e2672e024393d82a1d3F28);
  address public rewardPool = address(0xBC07342D01fF5D72021Bb4cb95F07C252e575309);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);
  address public mvixy = address(0xf72FCd9DCF0190923Fadd44811E240Ef4533fc86);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXRewardStrategyWithBuyback(_storage, mvixy_ust, _vault, rewardPool, mir, uniswapRouterAddress, _distributionPool, 5000)
  public {
    require(IVault(_vault).underlying() == mvixy_ust, "Underlying mismatch");
    uniswapRoutes[mvixy] = [mir, ust, mvixy];
    uniswapRoutes[ust] = [mir, ust];
  }
}
