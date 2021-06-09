pragma solidity 0.5.16;

import "./ConvexStrategy4Token.sol";

contract ConvexStrategyUSTMainnet is ConvexStrategy4Token {

  address public ust_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x94e131324b6054c0D789b190b2dAC504e4361b53);
    address rewardPool = address(0xd4Be1911F8a0df178d6e7fF5cE39919c273E2B7B);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address ustCurveDeposit = address(0xB0a0716841F2Fc03fbA72A891B8Bb13584F52F2d);
    ConvexStrategy4Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      21,  // Pool id
      dai,
      1, //depositArrayPosition
      ustCurveDeposit
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
