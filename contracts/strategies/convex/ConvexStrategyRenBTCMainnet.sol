pragma solidity 0.5.16;

import "./ConvexStrategy2Token.sol";

contract ConvexStrategyRenBTCMainnet is ConvexStrategy2Token {

  address public renbtc_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x49849C98ae39Fff122806C06791Fa73784FB3675);
    address rewardPool = address(0x8E299C62EeD737a5d5a53539dF37b5356a27b07D);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address renbtcCurveDeposit = address(0x93054188d876f558f4a66B2EF1d97d16eDf0895B);
    ConvexStrategy2Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      6,  // Pool id
      wbtc,
      1, //depositArrayPosition
      renbtcCurveDeposit
    );
    reward2WETH[crv] = [crv, weth];
    reward2WETH[cvx] = [cvx, weth];
    WETH2deposit = [weth, wbtc];
    rewardTokens = [crv, cvx];
    useUni[crv] = false;
    useUni[cvx] = false;
    useUni[wbtc] = false;
  }
}
