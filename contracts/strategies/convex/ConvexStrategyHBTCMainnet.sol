pragma solidity 0.5.16;

import "./ConvexStrategy2Token.sol";

contract ConvexStrategyHBTCMainnet is ConvexStrategy2Token {

  address public hbtc_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xb19059ebb43466C323583928285a49f558E572Fd);
    address rewardPool = address(0x618BD6cBA676a46958c63700C04318c84a7b7c0A);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address hbtcCurveDeposit = address(0x4CA9b3063Ec5866A4B82E437059D2C43d1be596F);
    ConvexStrategy2Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      8,  // Pool id
      wbtc,
      1, //depositArrayPosition
      hbtcCurveDeposit
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
