pragma solidity 0.5.16;

import "./base/ConvexStrategyLP.sol";

contract ConvexStrategyLPMainnet_CVX_ETH is ConvexStrategyLP {

  address public cvx_eth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x05767d9EF41dC40689678fFca0608878fb3dE906);
    address rewardPool = address(0xEF0881eC094552b2e128Cf945EF17a6752B4Ec5d);
    address sushi = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    ConvexStrategyLP.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool,
      1  // Pool id
    );
    reward2WETH[sushi] = [sushi, weth];
    reward2WETH[cvx] = [cvx, weth];
    WETH2deposit[cvx] = [weth, cvx];
    rewardTokens = [sushi, cvx];
    useUni[sushi] = false;
    useUni[cvx] = false;
  }
}
