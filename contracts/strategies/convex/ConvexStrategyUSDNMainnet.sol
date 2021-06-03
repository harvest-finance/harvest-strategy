pragma solidity 0.5.16;

import "./ConvexStrategy4Token.sol";

contract ConvexStrategyUSDNMainnet is ConvexStrategy4Token {

  address public usdn_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x4f3E8F405CF5aFC05D68142F3783bDfE13811522);
    address rewardPool = address(0x4a2631d090e8b40bBDe245e687BF09e5e534A239);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address usdnCurveDeposit = address(0x094d12e5b541784701FD8d65F11fc0598FBC6332);
    ConvexStrategy4Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      13,  // Pool id
      dai,
      1, //depositArrayPosition
      usdnCurveDeposit
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
