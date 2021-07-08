pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./BalancerStrategyRatio.sol";

contract BalancerStrategyMainnet_DAI_WETH is BalancerStrategyRatio {

  address public dai_weth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x0b09deA16768f0799065C475bE02919503cB2a35);
    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
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
      0x0b09dea16768f0799065c475be02919503cb2a3500020000000000000000001a,  // Pool id
      500, //Liquidation ratio, liquidate 50% on doHardWork
      400 //Ratio, token0 = BAL, 40% of pool
    );
    storedLiquidationPaths[bal][dai] = [bal, dai];
    storedLiquidationDexes[bal][dai] = [uniDex];
    storedLiquidationPaths[bal][weth] = [bal, weth];
    storedLiquidationDexes[bal][weth] = [uniDex];
  }
}
