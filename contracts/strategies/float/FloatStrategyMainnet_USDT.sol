pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategy.sol";

contract FloatStrategyMainnet_USDT is SNXRewardStrategy {

  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public usdt = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
  address public bank = address(0x24A6A37576377F63f194Caa5F518a60f45b42921);
  address public rewardPoolAddr = address(0xC6D58F8c684F0F2992bA613d209209897c298E44);
  address public constant sushiswapRouterAddress = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F); //BANK LP is on sushi

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardStrategy(_storage, usdt, _vault, bank, sushiswapRouterAddress)
  public {
    rewardPool = SNXRewardInterface(rewardPoolAddr);
    liquidationPath = [bank, weth, usdt];
  }
}
