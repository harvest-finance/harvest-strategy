pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXReward2FarmStrategy.sol";

contract MirrorMainnet_mAMZN_UST is SNXReward2FarmStrategy {

  address public mAMZN_UST = address(0x0Ae8cB1f57e3b1b7f4f5048743710084AA69E796);
  address public rewardPool = address(0x1fABef2C2DAB77f01053E9600F70bE1F3F657F51);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public farm = address(0xa0246c9032bC3A600820415aE600c6388619A14D);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool,
    address _distributionSwitcher
  )
  SNXReward2FarmStrategy(_storage, mAMZN_UST, _vault, rewardPool, mir, uniswapRouterAddress, farm, _distributionPool, _distributionSwitcher)
  public {
    require(IVault(_vault).underlying() == mAMZN_UST, "Underlying mismatch");
    uniswapRoutes[farm] = [mir, weth, farm];

    // adding ability to liquidate reward tokens manually if there is no liquidity
    unsalvagableTokens[mir] = false;
  }
}
