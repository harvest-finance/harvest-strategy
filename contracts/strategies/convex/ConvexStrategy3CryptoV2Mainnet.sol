pragma solidity 0.5.16;

import "./base/ConvexStrategy3Token.sol";

contract ConvexStrategy3CryptoV2Mainnet is ConvexStrategy3Token {

  address public threecryptoV2_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xc4AD29ba4B3c580e6D59105FFf484999997675Ff);
    address rewardPool = address(0x9D5C5E364D81DaB193b72db9E9BE9D8ee669B652);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address usdt = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address threecryptoCurveDeposit = address(0x3993d34e7e99Abf6B6f367309975d1360222D446);
    ConvexStrategy3Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      38,  // Pool id
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
