pragma solidity 0.5.16;

import "./interface/IETHPhase2Pool.sol";
import "./FloatStrategyETH.sol";

contract FloatStrategyETHMainnet is FloatStrategyETH {

  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public bank = address(0x24A6A37576377F63f194Caa5F518a60f45b42921);
  address payable public rewardPoolAddr = address(0x5Cc2dB43F9c2E2029AEE159bE60A9ddA50b05D4A);
  address public constant sushiswapRouterAddress = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F); //BANK LP is on sushi

  constructor(
    address _storage,
    address _vault
  )
  FloatStrategyETH(_storage, weth, _vault, bank, sushiswapRouterAddress)
  public {
    rewardPool = IETHPhase2Pool(rewardPoolAddr);
    liquidationPath = [bank, weth];
  }
}
