pragma solidity 0.5.16;

import "./ConvexStrategy4Token.sol";

contract ConvexStrategyHUSDMainnet is ConvexStrategy4Token {

  address public husd_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x5B5CFE992AdAC0C9D48E05854B2d91C73a003858);
    address rewardPool = address(0x353e489311b21355461353fEC2d02B73EF0eDe7f);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address husdCurveDeposit = address(0x09672362833d8f703D5395ef3252D4Bfa51c15ca);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ConvexStrategy4Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      crv,
      11,  // Pool id
      dai,
      1, //depositArrayPosition
      husdCurveDeposit
    );
    liquidationPath = [crv, weth, dai];
    pathCVX2CRV = [cvx, weth, crv];
  }
}
