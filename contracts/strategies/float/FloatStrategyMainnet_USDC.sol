pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategy.sol";

contract FloatStrategyMainnet_USDC is SNXRewardStrategy {

  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  address public bank = address(0x24A6A37576377F63f194Caa5F518a60f45b42921);
  address public rewardPoolAddr = address(0xeD7df34c629F46de7C31069C7816dD6D8654DD17);
  address public constant sushiswapRouterAddress = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F); //BANK LP is on sushi

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardStrategy(_storage, usdc, _vault, bank, sushiswapRouterAddress)
  public {
    rewardPool = SNXRewardInterface(rewardPoolAddr);
    liquidationPath = [bank, weth, usdc];
  }
}
