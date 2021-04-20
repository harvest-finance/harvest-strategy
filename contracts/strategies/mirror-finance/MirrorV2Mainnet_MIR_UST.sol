pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategyWithBuyback.sol";

contract MirrorV2Mainnet_MIR_UST is SNXRewardStrategyWithBuyback {

  address public mir_ust = address(0x87dA823B6fC8EB8575a235A824690fda94674c88);
  address public rewardPool = address(0x5d447Fc0F8965cED158BAB42414Af10139Edf0AF);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXRewardStrategyWithBuyback(_storage, mir_ust, _vault, rewardPool, mir, uniswapRouterAddress, _distributionPool, 5000)
  public {
    require(IVault(_vault).underlying() == mir_ust, "Underlying mismatch");
    uniswapRoutes[ust] = [mir, ust];
  }
}
