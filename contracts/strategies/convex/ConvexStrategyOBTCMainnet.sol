pragma solidity 0.5.16;

import "./ConvexStrategy4Token.sol";

contract ConvexStrategyOBTCMainnet is ConvexStrategy4Token {

  address public obtc_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x2fE94ea3d5d4a175184081439753DE15AeF9d614);
    address rewardPool = address(0xeeeCE77e0bc5e59c77fc408789A9A172A504bD2f);
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address bor = address(0x3c9d6c1C73b31c837832c72E04D3152f051fc1A9);
    address wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address obtcCurveDeposit = address(0xd5BCf53e2C81e1991570f33Fa881c49EEa570C8D);
    ConvexStrategy4Token.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, //rewardPool
      20,  // Pool id
      wbtc,
      2, //depositArrayPosition
      obtcCurveDeposit
    );
    reward2WETH[crv] = [crv, weth];
    reward2WETH[cvx] = [cvx, weth];
    reward2WETH[bor] = [bor, weth];
    WETH2deposit = [weth, wbtc];
    rewardTokens = [crv, cvx, bor];
    useUni[crv] = false;
    useUni[cvx] = false;
    useUni[wbtc] = false;
    useUni[bor] = false;
  }
}
