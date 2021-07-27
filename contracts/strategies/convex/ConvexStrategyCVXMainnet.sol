pragma solidity 0.5.16;

import "./base/ConvexStrategyCVX.sol";

contract ConvexStrategyCVXMainnet is ConvexStrategyCVX {

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address rewardPool = address(0xCF50b810E57Ac33B91dCF525C6ddd9881B139332);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address cvxcrv = address(0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ConvexStrategyCVX.initializeBaseStrategy(
      _storage,
      cvx,
      _vault,
      rewardPool,
      cvxcrv
    );
    liquidationPath = [cvxcrv, crv, weth, cvx];
  }
}
