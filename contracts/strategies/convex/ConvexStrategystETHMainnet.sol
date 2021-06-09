pragma solidity 0.5.16;

import "./ConvexStrategystETH.sol";

contract ConvexStrategystETHMainnet is ConvexStrategystETH {

  address public steth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x06325440D014e39736583c165C2963BA99fAf14E);
    address rewardPool = address(0x0A760466E1B4621579a82a39CB56Dda2F4E70f03);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address ldo = address(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32);
    address stethCurveDeposit = address(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ConvexStrategystETH.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      25,  // Pool id
      address(0), //ETH
      0, //depositArrayPosition
      stethCurveDeposit
    );
    reward2WETH[crv] = [crv, weth];
    reward2WETH[cvx] = [cvx, weth];
    reward2WETH[ldo] = [ldo, weth];
    rewardTokens = [crv, cvx, ldo];
  }
}
