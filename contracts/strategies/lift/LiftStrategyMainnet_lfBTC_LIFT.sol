pragma solidity 0.5.16;

import "./LiftStrategy.sol";

contract LiftStrategyMainnet_lfBTC_LIFT is LiftStrategy {

  address public lfBTC_LIFT = address(0x0e250c3FF736491712C5b11EcEe6d8dbFA41c78f);
  address public lfBTC = address(0xafcE9B78D409bF74980CACF610AFB851BF02F257);
  address public LIFT = address(0xf9209d900f7ad1DC45376a2caA61c78f6dEA53B6);
  address public lfBTCLIFTRewardPool = address(0xC3C79869ED93c88E1227a1Ca3542c9B947BA9e0c);
  address public constant sushiRouterAddress = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

  constructor(
    address _storage,
    address _vault
  )
  LiftStrategy(_storage, lfBTC_LIFT, _vault, lfBTCLIFTRewardPool, LIFT, sushiRouterAddress)
  public {

  }
}
