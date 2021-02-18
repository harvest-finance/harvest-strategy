pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategy.sol";

contract BasisGoldStrategyMainnet_ESD is SNXRewardStrategy {

  address public usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  address public dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address public esd = address(0x36F3FD68E7325a35EB768F1AedaAe9EA0689d723);
  address public bsg = address(0xB34Ab2f65c6e4F764fFe740ab83F982021Faed6d);
  address public BSGESDRewardPool = address(0xD22df8A977F616731f31864335Bf31bD0b38f2B6);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardStrategy(_storage, esd, _vault, bsg, uniswapRouterAddress)
  public {
    rewardPool = SNXRewardInterface(BSGESDRewardPool);
    liquidationPath = [bsg, dai, usdc, esd];
  }
}
