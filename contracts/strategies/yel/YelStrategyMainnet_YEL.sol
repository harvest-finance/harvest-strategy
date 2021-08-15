pragma solidity 0.5.16;

import "./YelStrategy.sol";

contract YelStrategyMainnet_YEL is YelStrategy {

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address yel = address(0x7815bDa662050D84718B988735218CFfd32f75ea);
    YelStrategy.initializeStrategy(
      _storage,
      yel,
      _vault,
      address(0xe7c8477C0c7AAaD6106EBDbbED3a5a2665b273b9), // master chef contract
      yel,
      0  // Pool id
    );
  }
}
