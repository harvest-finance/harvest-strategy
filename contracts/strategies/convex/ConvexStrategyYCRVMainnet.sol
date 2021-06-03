pragma solidity 0.5.16;

import "./ConvexStrategy4Token.sol";

contract ConvexStrategyYCRVMainnet is ConvexStrategy4Token {

  address public ycrv_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xdF5e0e81Dff6FAF3A7e52BA697820c5e32D806A8);
    address rewardPool = address(0xd802a8351A76ED5eCd89A7502Ca615F2225A585d);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address ycrvCurveDeposit = address(0xbBC81d23Ea2c3ec7e56D39296F0cbB648873a5d3);
    ConvexStrategy4Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      2,  // Pool id
      dai,
      0, //depositArrayPosition
      ycrvCurveDeposit
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
