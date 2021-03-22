pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardStrategy.sol";

contract FloatStrategyMainnet_SUSHI is SNXRewardStrategy {

  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public sushi = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
  address public bank = address(0x24A6A37576377F63f194Caa5F518a60f45b42921);
  address public rewardPoolAddr = address(0xA9e43Ae740A19ddd7Aa04efa4198b32344F4c0f2);
  address public constant sushiswapRouterAddress = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F); //BANK LP is on sushi

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardStrategy(_storage, sushi, _vault, bank, sushiswapRouterAddress)
  public {
    rewardPool = SNXRewardInterface(rewardPoolAddr);
    liquidationPath = [bank, weth, sushi];
  }
}
