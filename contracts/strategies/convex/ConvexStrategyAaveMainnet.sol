pragma solidity 0.5.16;

import "./base/ConvexStrategyAave.sol";

contract ConvexStrategyAaveMainnet is ConvexStrategyAave {

  address public aave_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xFd2a8fA60Abd58Efe3EeE34dd494cD491dC14900);
    address rewardPool = address(0xE82c1eB4BC6F92f85BF7EB6421ab3b882C3F5a7B);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address aave = address(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address aaveCurveDeposit = address(0xDeBF20617708857ebe4F679508E7b7863a8A8EeE);
    ConvexStrategyAave.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      24,  // Pool id
      dai,
      0, //depositArrayPosition
      aaveCurveDeposit
    );
    reward2WETH[crv] = [crv, weth];
    reward2WETH[cvx] = [cvx, weth];
    reward2WETH[aave] = [aave, weth];
    WETH2deposit = [weth, dai];
    rewardTokens = [crv, cvx, aave];
    useUni[crv] = false;
    useUni[cvx] = false;
    useUni[aave] = false;
    useUni[dai] = false;
  }
}
