pragma solidity 0.5.16;

import "./YelHodlStrategy.sol";

contract YelHodlStrategyMainnet_YEL_WETH is YelHodlStrategy {

  address public yel_weth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xc83cE8612164eF7A13d17DDea4271DD8e8EEbE5d);
    address yel = address(0x7815bDa662050D84718B988735218CFfd32f75ea);
    YelHodlStrategy.initializeMasterChefHodlStrategy(
      _storage,
      underlying,
      _vault,
      address(0xe7c8477C0c7AAaD6106EBDbbED3a5a2665b273b9), // master chef contract
      yel,
      1,  // Pool id
      address(0x0000000000000000000000000000000000000000), // manually set it later
      address(0x0000000000000000000000000000000000000000) // manually set it later
    );
  }
}
