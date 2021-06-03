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
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address husdCurveDeposit = address(0x09672362833d8f703D5395ef3252D4Bfa51c15ca);
    ConvexStrategy4Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      11,  // Pool id
      dai,
      1, //depositArrayPosition
      husdCurveDeposit
    );
    reward2WETH[crv] = [crv, weth];
    reward2WETH[cvx] = [cvx, weth];
    WETH2deposit = [weth, dai];
    rewardTokens = [crv, cvx];
    useUni[crv] = false;
    useUni[cvx] = false;
    useUni[dai] = false;
  }
}
