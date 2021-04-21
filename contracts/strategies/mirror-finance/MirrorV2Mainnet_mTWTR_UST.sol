pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategyWithBuyback.sol";

contract MirrorV2Mainnet_mTWTR_UST is SNXRewardStrategyWithBuyback {

  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);
  address public mtwtr_ust = address(0x34856be886A2dBa5F7c38c4df7FD86869aB08040);
  address public mtwtr = address(0xEdb0414627E6f1e3F082DE65cD4F9C693D78CCA9);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public mTWTRUSTRewardPool = address(0x99d737ab0df10cdC99c6f64D0384ACd5C03AEF7F);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXRewardStrategyWithBuyback(_storage, mtwtr_ust, _vault, mTWTRUSTRewardPool, mir, uniswapRouterAddress, _distributionPool, 5000)
  public {
    uniswapRoutes[mtwtr] = [mir, ust, mtwtr];
    uniswapRoutes[ust] = [mir, ust];
    require(IVault(_vault).underlying() == mtwtr_ust, "Underlying mismatch");
  }
}
