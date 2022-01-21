pragma solidity 0.5.16;

import "./base/ConvexStrategyUL.sol";

contract ConvexStrategyCVX_ETHMainnet is ConvexStrategyUL {

  address public cvx_eth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x3A283D9c08E8b55966afb64C515f5143cf907611); // Info -> LP Token address
    address rewardPool = address(0xb1Fb0BA0676A1fFA83882c7F4805408bA232C1fA); // Info -> Rewards contract address
    address crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address cvx = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address curveDeposit = address(0xB576491F1E6e5E62f1d8F26062Ee822B40B0E0d4); // only needed if deposits are not via underlying
    bytes32 sushiDex = bytes32(0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a);
    ConvexStrategyUL.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool, // rewardPool
      64,  // Pool id: Info -> Rewards contract address -> read -> pid
      cvx, // depositToken
      1, //depositArrayPosition. Find deposit transaction -> input params 
      curveDeposit, // deposit contract: usually underlying. Find deposit transaction -> interacted contract 
      2, //nTokens -> total number of deposit tokens
      false, //metaPool -> if LP token address == pool address (at curve)
      1000 // hodlRatio 10%
    );

    _setRewardToken(cvx);

    // deposit token is the same as reward token, less liquidations necessary
    // we only have to swap cvx -> crv
    rewardTokens = [crv, cvx];
    storedLiquidationPaths[crv][cvx] = [crv, cvx];
    storedLiquidationDexes[crv][cvx] = [sushiDex];
  }
}
