pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategy.sol";

contract KlondikeStrategyMainnet_renBTC is SNXRewardStrategy {

  address public renBTC = address(0xEB4C2781e4ebA804CE9a9803C67d0893436bB27D);
  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
  address public kbtc = address(0xE6C3502997f97F9BDe34CB165fBce191065E068f);
  address public KlonRenBTCRewardPool = address(0x4110D9A6b9aB2e388d572237284e74768342E0DA);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardStrategy(_storage, renBTC, _vault, kbtc, uniswapRouterAddress)
  public {
    rewardPool = SNXRewardInterface(KlonRenBTCRewardPool);
    liquidationPath = [kbtc, wbtc, weth, renBTC];
  }
}
