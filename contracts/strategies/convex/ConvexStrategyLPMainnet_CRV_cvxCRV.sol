pragma solidity 0.5.16;

import "./base/ConvexStrategyLP.sol";

contract ConvexStrategyLPMainnet_CRV_cvxCRV is ConvexStrategyLP {

  address public crv_cvxcrv_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x33F6DDAEa2a8a54062E021873bCaEE006CdF4007);
    address rewardPool = address(0xEF0881eC094552b2e128Cf945EF17a6752B4Ec5d);
    address sushi = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvxcrv = address(0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7);
    ConvexStrategyLP.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool,
      2  // Pool id
    );
    reward2WETH[sushi] = [sushi, weth];
    reward2WETH[cvx] = [cvx, weth];
    WETH2deposit[crv] = [weth, crv];
    WETH2deposit[cvxcrv] = [weth, crv, cvxcrv];
    rewardTokens = [sushi, cvx];
    useUni[sushi] = false;
    useUni[cvx] = false;
    useUni[crv] = false;
    useUni[cvxcrv] = false;
  }
}
