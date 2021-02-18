pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardUniLPStrategy.sol";

contract BasisGoldStrategyMainnet_DAI_BSGS is SNXRewardUniLPStrategy {

  address public dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address public dai_bsgs = address(0x980a07E4F64d21a0cB2eF8D4AF362a79b9f5c0DA);
  address public bsgs = address(0xA9d232cC381715aE791417B624D7C4509D2c28DB);
  address public DAIBSGSRewardPool = address(0x3B871056E9f13aA3BA5b4dC3f71f00f7dc652199);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardUniLPStrategy(_storage, dai_bsgs, _vault, DAIBSGSRewardPool, bsgs, uniswapRouterAddress)
  public {
    require(IVault(_vault).underlying() == dai_bsgs, "Underlying mismatch");
    // token0 is DAI, token1 is BSGS
    uniswapRoutes[uniLPComponentToken0] = [bsgs, dai];
    uniswapRoutes[uniLPComponentToken1] = [bsgs];
  }
}
