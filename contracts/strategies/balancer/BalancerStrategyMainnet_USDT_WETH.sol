pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./BalancerStrategy.sol";

contract BalancerStrategyMainnet_USDT_WETH is BalancerStrategy {

  address public usdt_weth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x3e5FA9518eA95c3E533EB377C001702A9AaCAA32);
    address usdt = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address bal = address(0xba100000625a3754423978a60c9317c58a424e3D);
    bytes32 uniDex = 0xde2d1a51640f78257713031680d1f306297d957426e912ab21317b9cc9495a41;
    BalancerStrategy.initializeStrategy(
      _storage,
      underlying,
      _vault,
      address(0x6d19b2bF3A36A61530909Ae65445a906D98A2Fa8), // claiming contract
      bal,
      address(0xBA12222222228d8Ba445958a75a0704d566BF2C8), //balancer vault
      0x3e5fa9518ea95c3e533eb377c001702a9aacaa32000200000000000000000052,  // Pool id
      500 //Liquidation ratio, liquidate 50% on doHardWork
    );
    storedLiquidationPaths[bal][usdt] = [bal, usdt];
    storedLiquidationDexes[bal][usdt] = [uniDex];
    storedLiquidationPaths[bal][weth] = [bal, weth];
    storedLiquidationDexes[bal][weth] = [uniDex];
  }
}
