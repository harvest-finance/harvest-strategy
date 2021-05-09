pragma solidity 0.5.16;

import "../../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../../base/snx-base/SNXRewardStrategyWithBuyback.sol";

contract MirrorV2Mainnet_mIAU_UST is SNXRewardStrategyWithBuyback {

  address public miau_ust = address(0xd7f97aa0317C08A1F5C2732e7894933f11724868);
  address public rewardPool = address(0xE214a6ca22BE90f011f34FDddC7c5A07800F8BCd);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);
  address public miau = address(0x1d350417d9787E000cc1b95d70E9536DcD91F373);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXRewardStrategyWithBuyback(_storage, miau_ust, _vault, rewardPool, mir, uniswapRouterAddress, _distributionPool, 5000)
  public {
    require(IVault(_vault).underlying() == miau_ust, "Underlying mismatch");
    uniswapRoutes[miau] = [mir, ust, miau];
    uniswapRoutes[ust] = [mir, ust];
  }
}
