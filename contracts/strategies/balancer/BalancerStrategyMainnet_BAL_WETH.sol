pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./BalancerStrategyRatio.sol";

contract BalancerStrategyMainnet_BAL_WETH is BalancerStrategyRatio {

  address public bal_weth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address bal = address(0xba100000625a3754423978a60c9317c58a424e3D);
    bytes32 uniDex = 0xde2d1a51640f78257713031680d1f306297d957426e912ab21317b9cc9495a41;
    BalancerStrategyRatio.initializeStrategy(
      _storage,
      underlying,
      _vault,
      address(0x6d19b2bF3A36A61530909Ae65445a906D98A2Fa8), // claiming contract
      bal,
      address(0xBA12222222228d8Ba445958a75a0704d566BF2C8), //balancer vault
      0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014,  // Pool id
      500, //Liquidation ratio, liquidate 50% on doHardWork
      800 //Pool ratio, token0 = BAL, 80% of pool
    );
    storedLiquidationPaths[bal][weth] = [bal, weth];
    storedLiquidationDexes[bal][weth] = [uniDex];
  }
}
