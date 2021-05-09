pragma solidity 0.5.16;

import "../../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../../base/snx-base/SNXRewardStrategyWithBuyback.sol";

contract MirrorV2Mainnet_mBABA_UST is SNXRewardStrategyWithBuyback {

  address public mbaba_ust = address(0x676Ce85f66aDB8D7b8323AeEfe17087A3b8CB363);
  address public rewardPool = address(0x769325E8498bF2C2c3cFd6464A60fA213f26afcc);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);
  address public mbaba = address(0x56aA298a19C93c6801FDde870fA63EF75Cc0aF72);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXRewardStrategyWithBuyback(_storage, mbaba_ust, _vault, rewardPool, mir, uniswapRouterAddress, _distributionPool, 5000)
  public {
    require(IVault(_vault).underlying() == mbaba_ust, "Underlying mismatch");
    uniswapRoutes[mbaba] = [mir, ust, mbaba];
    uniswapRoutes[ust] = [mir, ust];
  }
}
