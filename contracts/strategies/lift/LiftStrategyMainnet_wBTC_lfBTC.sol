pragma solidity 0.5.16;

import "./LiftStrategy.sol";

contract LiftStrategyMainnet_wBTC_lfBTC is LiftStrategy {

  address public wBTC_lfBTC = address(0xd975b774C50aa0aEacB7b546b86218c1D7362123);
  address public lfBTC = address(0xafcE9B78D409bF74980CACF610AFB851BF02F257);
  address public wBTC = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
  address public LIFT = address(0xf9209d900f7ad1DC45376a2caA61c78f6dEA53B6);
  address public wBTClfBTCRewardPool = address(0x4DB2fa451e1051A013A42FaD98b04C2aB81043Af);
  address public constant sushiRouterAddress = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

  constructor(
    address _storage,
    address _vault
  )
  LiftStrategy(_storage, wBTC_lfBTC, _vault, wBTClfBTCRewardPool, LIFT, sushiRouterAddress)
  public {

  }
}
