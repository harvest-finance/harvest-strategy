pragma solidity 0.5.16;

import "./ConvexStrategy4Token.sol";

contract ConvexStrategyTBTCMainnet is ConvexStrategy4Token {

  address public tbtc_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x64eda51d3Ad40D56b9dFc5554E06F94e1Dd786Fd);
    address rewardPool = address(0x081A6672f07B615B402e7558a867C97FA080Ce35);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address keep = address(0x85Eee30c52B0b379b046Fb0F85F4f3Dc3009aFEC);
    address wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address tbtcCurveDeposit = address(0xaa82ca713D94bBA7A89CEAB55314F9EfFEdDc78c);
    ConvexStrategy4Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      16,  // Pool id
      wbtc,
      2, //depositArrayPosition
      tbtcCurveDeposit
    );
    reward2WETH[crv] = [crv, weth];
    reward2WETH[cvx] = [cvx, weth];
    reward2WETH[keep] = [keep, weth];
    WETH2deposit = [weth, wbtc];
    rewardTokens = [crv, cvx, keep];
    useUni[crv] = false;
    useUni[cvx] = false;
    useUni[wbtc] = false;
    useUni[keep] = true;
  }
}
