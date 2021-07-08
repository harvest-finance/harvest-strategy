pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./BalancerStrategy.sol";

contract BalancerStrategyMainnet_USDC_WETH is BalancerStrategy {

  address public usdc_weth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x96646936b91d6B9D7D0c47C496AfBF3D6ec7B6f8);
    address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
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
      0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019,  // Pool id
      500 //Liquidation ratio, liquidate 50% on doHardWork
    );
    storedLiquidationPaths[bal][usdc] = [bal, usdc];
    storedLiquidationDexes[bal][usdc] = [uniDex];
    storedLiquidationPaths[bal][weth] = [bal, weth];
    storedLiquidationDexes[bal][weth] = [uniDex];
  }
}
