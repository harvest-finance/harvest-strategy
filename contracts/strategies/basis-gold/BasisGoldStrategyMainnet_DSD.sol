pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategy.sol";

contract BasisGoldStrategyMainnet_DSD is SNXRewardStrategy {

  address public usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  address public dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address public dsd = address(0xBD2F0Cd039E0BFcf88901C98c0bFAc5ab27566e3);
  address public bsg = address(0xB34Ab2f65c6e4F764fFe740ab83F982021Faed6d);
  address public BSGDSDRewardPool = address(0x5B85877D33Ca6B86F0F82329f24ca82BdeDd09AC);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardStrategy(_storage, dsd, _vault, bsg, uniswapRouterAddress)
  public {
    rewardPool = SNXRewardInterface(BSGDSDRewardPool);
    liquidationPath = [bsg, dai, usdc, dsd];
  }
}
