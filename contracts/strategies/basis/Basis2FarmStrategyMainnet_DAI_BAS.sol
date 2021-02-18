pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXReward2FarmStrategyV2.sol";

contract Basis2FarmStrategyMainnet_DAI_BAS is SNXReward2FarmStrategyV2 {

  address public constant __dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address public constant __bac = address(0x3449FC1Cd036255BA1EB19d65fF4BA2b8903A69a);
  address public constant __bas = address(0xa7ED29B253D8B4E3109ce07c80fc570f81B63696);

  address public constant __dai_bas = address(0x0379dA7a5895D13037B6937b109fA8607a659ADF);
  address public constant __rewardPool = address(0x9569d4CD7AC5B010DA5697E952EFB1EC0Efb0D0a);

  address public constant __uniswapRouterV2 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public constant __sushiswapRouterV2 = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

  address public constant __farm = address(0xa0246c9032bC3A600820415aE600c6388619A14D);
  address public constant __weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant __notifyHelper = address(0xE20c31e3d08027F5AfACe84A3A46B7b3B165053c);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool,
    address _distributionSwitcher
  )
  SNXReward2FarmStrategyV2(
    _storage,
    __dai_bas,
    _vault,
    __rewardPool,
    __bas,
    __uniswapRouterV2,
    __sushiswapRouterV2,
    __farm,
    __weth,
    _distributionPool,
    _distributionSwitcher
  )
  public {
    require(IVault(_vault).underlying() == __dai_bas, "Underlying mismatch");
    liquidateRewardToWethInSushi = false;
    liquidationRoutes[__bas] = [__bas, __dai, __weth, __farm];
    autoRevertRewardDistribution = false;
    defaultRewardDistribution = __notifyHelper;
  }
}
