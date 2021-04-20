pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategyWithBuyback.sol";

contract MirrorV2Mainnet_mAMZN_UST is SNXRewardStrategyWithBuyback {

  address public mAMZN_UST = address(0x0Ae8cB1f57e3b1b7f4f5048743710084AA69E796);
  address public rewardPool = address(0x1fABef2C2DAB77f01053E9600F70bE1F3F657F51);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);
  address public mAMZN = address(0x0cae9e4d663793c2a2A0b211c1Cf4bBca2B9cAa7);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXRewardStrategyWithBuyback(_storage, mAMZN_UST, _vault, rewardPool, mir, uniswapRouterAddress, _distributionPool, 5000)
  public {
    require(IVault(_vault).underlying() == mAMZN_UST, "Underlying mismatch");
    uniswapRoutes[mAMZN] = [mir, ust, mAMZN];
    uniswapRoutes[ust] = [mir, ust];
  }
}
