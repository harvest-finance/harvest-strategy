pragma solidity 0.5.16;

import "./ConvexStrategy2Token.sol";

contract ConvexStrategyLinkMainnet is ConvexStrategy2Token {

  address public link_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xcee60cFa923170e4f8204AE08B4fA6A3F5656F3a);
    address rewardPool = address(0x9700152175dc22E7d1f3245fE3c1D2cfa3602548);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address link = address(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    address linkCurveDeposit = address(0xF178C0b5Bb7e7aBF4e12A4838C7b7c5bA2C623c0);
    ConvexStrategy2Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      30,  // Pool id
      link,
      0, //depositArrayPosition
      linkCurveDeposit
    );
    reward2WETH[crv] = [crv, weth];
    reward2WETH[cvx] = [cvx, weth];
    WETH2deposit = [weth, link];
    rewardTokens = [crv, cvx];
    useUni[crv] = false;
    useUni[cvx] = false;
    useUni[link] = false;
  }
}
