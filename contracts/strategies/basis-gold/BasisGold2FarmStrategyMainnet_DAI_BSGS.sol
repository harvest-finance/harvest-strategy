pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXReward2FarmStrategy.sol";

contract BasisGold2FarmStrategyMainnet_DAI_BSGS is SNXReward2FarmStrategy {

  address public dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address public dai_bsgs = address(0x980a07E4F64d21a0cB2eF8D4AF362a79b9f5c0DA);
  address public bsg = address(0xB34Ab2f65c6e4F764fFe740ab83F982021Faed6d);
  address public bsgs = address(0xA9d232cC381715aE791417B624D7C4509D2c28DB);
  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public DAIBSGSRewardPool = address(0x3B871056E9f13aA3BA5b4dC3f71f00f7dc652199);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public constant farm = address(0xa0246c9032bC3A600820415aE600c6388619A14D);
  address[] uniswapRouteFarm = [bsgs, dai, weth, farm];

  constructor(
    address _storage,
    address _vault,
    address _distributionPool,
    address _distributionSwitcher
  )
  SNXReward2FarmStrategy(_storage, dai_bsgs, _vault, DAIBSGSRewardPool, bsgs, uniswapRouterAddress, farm, _distributionPool, _distributionSwitcher)
  public {
    require(IVault(_vault).underlying() == dai_bsgs, "Underlying mismatch");
    uniswapRoutes[farm] = uniswapRouteFarm;
  }
}
