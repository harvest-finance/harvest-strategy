pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategyWithBuyback.sol";

contract MirrorV2Mainnet_mGOOG_UST is SNXRewardStrategyWithBuyback {

  address public mGOOG_UST = address(0x4b70ccD1Cf9905BE1FaEd025EADbD3Ab124efe9a);
  address public rewardPool = address(0x5b64BB4f69c8C03250Ac560AaC4C7401d78A1c32);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);
  address public mgoog = address(0x59A921Db27Dd6d4d974745B7FfC5c33932653442);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXRewardStrategyWithBuyback(_storage, mGOOG_UST, _vault, rewardPool, mir, uniswapRouterAddress, _distributionPool, 5000)
  public {
    require(IVault(_vault).underlying() == mGOOG_UST, "Underlying mismatch");
    uniswapRoutes[mgoog] = [mir, ust, mgoog];
    uniswapRoutes[ust] = [mir, ust];
  }
}
