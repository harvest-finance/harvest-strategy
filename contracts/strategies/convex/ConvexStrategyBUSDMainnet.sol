pragma solidity 0.5.16;

import "./ConvexStrategy4Token.sol";

contract ConvexStrategyBUSDMainnet is ConvexStrategy4Token {

  address public busd_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x3B3Ac5386837Dc563660FB6a0937DFAa5924333B);
    address rewardPool = address(0x602c4cD53a715D8a7cf648540FAb0d3a2d546560);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address busdCurveDeposit = address(0xb6c057591E073249F2D9D88Ba59a46CFC9B59EdB);
    ConvexStrategy4Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      3,  // Pool id
      dai,
      0, //depositArrayPosition
      busdCurveDeposit
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
