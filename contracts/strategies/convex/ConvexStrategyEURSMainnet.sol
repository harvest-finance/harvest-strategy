pragma solidity 0.5.16;

import "./ConvexStrategy2Token.sol";

contract ConvexStrategyEURSMainnet is ConvexStrategy2Token {

  address public eurs_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x194eBd173F6cDacE046C53eACcE9B953F28411d1);
    address rewardPool = address(0xcB8F69E0064d8cdD29cbEb45A14cf771D904BcD3);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address eurs = address(0xdB25f211AB05b1c97D595516F45794528a807ad8);
    address eursCurveDeposit = address(0x0Ce6a5fF5217e38315f87032CF90686C96627CAA);
    address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ConvexStrategy2Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      22,  // Pool id
      eurs,
      0, //depositArrayPosition
      eursCurveDeposit
    );
    reward2WETH[crv] = [crv, weth];
    reward2WETH[cvx] = [cvx, weth];
    WETH2deposit = [weth, usdc, eurs];
    rewardTokens = [crv, cvx];
    useUni[crv] = false;
    useUni[cvx] = false;
    useUni[eurs] = false;
  }
}
