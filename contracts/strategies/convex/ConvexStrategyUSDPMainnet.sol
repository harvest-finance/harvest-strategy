pragma solidity 0.5.16;

import "./ConvexStrategy4Token.sol";

contract ConvexStrategyUSDPMainnet is ConvexStrategy4Token {

  address public usdp_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x7Eb40E450b9655f4B3cC4259BCC731c63ff55ae6);
    address rewardPool = address(0x24DfFd1949F888F91A0c8341Fc98a3F280a782a8);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address usdpCurveDeposit = address(0x3c8cAee4E09296800f8D29A68Fa3837e2dae4940);
    ConvexStrategy4Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      28,  // Pool id
      dai,
      1, //depositArrayPosition
      usdpCurveDeposit
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
