pragma solidity 0.5.16;

import "./ConvexStrategy3Token.sol";

contract ConvexStrategy3CRVMainnet is ConvexStrategy3Token {

  address public threecrv_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    address rewardPool = address(0x689440f2Ff927E1f24c72F1087E1FAF471eCe1c8);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address threecrvCurveDeposit = address(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ConvexStrategy3Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      crv,
      9,  // Pool id
      dai,
      0, //depositArrayPosition
      threecrvCurveDeposit
    );
    liquidationPath = [crv, weth, dai];
    pathCVX2CRV = [cvx, weth, crv];
  }
}
