pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategy.sol";

contract BasisGoldStrategyMainnet_DAI is SNXRewardStrategy {

  address public dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address public bsg = address(0xB34Ab2f65c6e4F764fFe740ab83F982021Faed6d);
  address public BSGDAIRewardPool = address(0xbBeCd4FC3C04769837DcA2305EeF53DC3cf4E620);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardStrategy(_storage, dai, _vault, bsg, uniswapRouterAddress)
  public {
    rewardPool = SNXRewardInterface(BSGDAIRewardPool);
    liquidationPath = [bsg, dai];
  }
}
