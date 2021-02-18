pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategy.sol";

contract BasisGoldStrategyMainnet_BAC is SNXRewardStrategy {

  address public dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address public bac = address(0x3449FC1Cd036255BA1EB19d65fF4BA2b8903A69a);
  address public bsg = address(0xB34Ab2f65c6e4F764fFe740ab83F982021Faed6d);
  address public BSGBACRewardPool = address(0x4330E43F5b1e7D3Ea7B0a177Af50C6B2489ca406);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardStrategy(_storage, bac, _vault, bsg, uniswapRouterAddress)
  public {
    rewardPool = SNXRewardInterface(BSGBACRewardPool);
    liquidationPath = [bsg, dai, bac];
  }
}
