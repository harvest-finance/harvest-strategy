pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXReward2FarmStrategy.sol";

contract BasisGold2FarmStrategyMainnet_DAI_BSG is SNXReward2FarmStrategy {

  address public dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address public dai_bsg = address(0x4A9596E5d2f9bEF50E4De092AD7181aE3C40353e);
  address public bsg = address(0xB34Ab2f65c6e4F764fFe740ab83F982021Faed6d);
  address public bsgs = address(0xA9d232cC381715aE791417B624D7C4509D2c28DB);
  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public DAIBSGRewardPool = address(0xAe49F34331f31e1C1ADA91213b47b4065a04516b);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public constant farm = address(0xa0246c9032bC3A600820415aE600c6388619A14D);
  address[] uniswapRouteFarm = [bsgs, dai, weth, farm];

  constructor(
    address _storage,
    address _vault,
    address _distributionPool,
    address _distributionSwitcher
  )
  SNXReward2FarmStrategy(_storage, dai_bsg, _vault, DAIBSGRewardPool, bsgs, uniswapRouterAddress, farm, _distributionPool, _distributionSwitcher)
  public {
    require(IVault(_vault).underlying() == dai_bsg, "Underlying mismatch");
    uniswapRoutes[farm] = uniswapRouteFarm;
  }
}
