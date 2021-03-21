pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategy.sol";

contract FloatStrategyMainnet_WBTC is SNXRewardStrategy {

  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
  address public bank = address(0x24A6A37576377F63f194Caa5F518a60f45b42921);
  address public rewardPoolAddr = address(0xE41F9FAbee859C4E6D248E9442c822F09742228a);
  address public constant sushiswapRouterAddress = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F); //BANK LP is on sushi

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardStrategy(_storage, wbtc, _vault, bank, sushiswapRouterAddress)
  public {
    rewardPool = SNXRewardInterface(rewardPoolAddr);
    liquidationPath = [bank, weth, wbtc];
  }
}
