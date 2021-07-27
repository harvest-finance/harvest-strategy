pragma solidity 0.5.16;

import "./base/ConvexStrategy3Token.sol";

contract ConvexStrategy3CryptoMainnet is ConvexStrategy3Token {

  address public threecrypto_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xcA3d75aC011BF5aD07a98d02f18225F9bD9A6BDF);
    address rewardPool = address(0x5Edced358e6C0B435D53CC30fbE6f5f0833F404F);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address usdt = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address threecryptoCurveDeposit = address(0x80466c64868E1ab14a1Ddf27A676C3fcBE638Fe5);
    ConvexStrategy3Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      37,  // Pool id
      usdt,
      0, //depositArrayPosition
      threecryptoCurveDeposit
    );
    reward2WETH[crv] = [crv, weth];
    reward2WETH[cvx] = [cvx, weth];
    WETH2deposit = [weth, usdt];
    rewardTokens = [crv, cvx];
    useUni[crv] = false;
    useUni[cvx] = false;
    useUni[usdt] = false;
  }
}
