pragma solidity 0.5.16;

import "./ConvexStrategy2Token.sol";

contract ConvexStrategyCompoundMainnet is ConvexStrategy2Token {

  address public compound_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x845838DF265Dcd2c412A1Dc9e959c7d08537f8a2);
    address rewardPool = address(0xf34DFF761145FF0B05e917811d488B441F33a968);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address compoundCurveDeposit = address(0xeB21209ae4C2c9FF2a86ACA31E123764A3B6Bc06);
    ConvexStrategy2Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      0,  // Pool id
      dai,
      0, //depositArrayPosition
      compoundCurveDeposit
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
