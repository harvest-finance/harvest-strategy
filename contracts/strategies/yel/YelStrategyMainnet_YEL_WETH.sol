pragma solidity 0.5.16;

import "./YelStrategy.sol";

contract YelStrategyMainnet_YEL_WETH is YelStrategy {

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xc83cE8612164eF7A13d17DDea4271DD8e8EEbE5d);
    address yel = address(0x7815bDa662050D84718B988735218CFfd32f75ea);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    YelStrategy.initializeStrategy(
      _storage,
      underlying,
      _vault,
      address(0xe7c8477C0c7AAaD6106EBDbbED3a5a2665b273b9), // master chef contract
      yel,
      1,  // Pool id
      true,
      false
    );
    swapRoutes[weth] = [yel, weth];
  }
}
