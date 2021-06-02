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
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address compoundCurveDeposit = address(0xeB21209ae4C2c9FF2a86ACA31E123764A3B6Bc06);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ConvexStrategy2Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      crv,
      0,  // Pool id
      dai,
      0, //depositArrayPosition
      compoundCurveDeposit
    );
    liquidationPath = [crv, weth, dai];
    pathCVX2CRV = [cvx, weth, crv];
  }
}
