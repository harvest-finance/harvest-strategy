pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardUniLPStrategy.sol";

contract BasisGoldStrategyMainnet_DAI_BSG is SNXRewardUniLPStrategy {

  address public dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address public dai_bsg = address(0x4A9596E5d2f9bEF50E4De092AD7181aE3C40353e);
  address public bsg = address(0xB34Ab2f65c6e4F764fFe740ab83F982021Faed6d);
  address public bsgs = address(0xA9d232cC381715aE791417B624D7C4509D2c28DB);
  address public DAIBSGRewardPool = address(0xAe49F34331f31e1C1ADA91213b47b4065a04516b);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardUniLPStrategy(_storage, dai_bsg, _vault, DAIBSGRewardPool, bsgs, uniswapRouterAddress)
  public {
    require(IVault(_vault).underlying() == dai_bsg, "Underlying mismatch");
    // token0 is DAI, token1 is BSG
    uniswapRoutes[uniLPComponentToken0] = [bsgs, dai];
    uniswapRoutes[uniLPComponentToken1] = [bsgs, dai, bsg];
  }
}
