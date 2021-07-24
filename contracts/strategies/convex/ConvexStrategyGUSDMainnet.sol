pragma solidity 0.5.16;

import "./base/ConvexStrategy4Token.sol";

contract ConvexStrategyGUSDMainnet is ConvexStrategy4Token {

  address public gusd_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xD2967f45c4f384DEEa880F807Be904762a3DeA07);
    address rewardPool = address(0x7A7bBf95C44b144979360C3300B54A7D34b44985);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address gusdCurveDeposit = address(0x64448B78561690B70E17CBE8029a3e5c1bB7136e);
    ConvexStrategy4Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      10,  // Pool id
      dai,
      1, //depositArrayPosition
      gusdCurveDeposit
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
