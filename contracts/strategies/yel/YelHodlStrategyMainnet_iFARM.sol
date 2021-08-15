pragma solidity 0.5.16;

import "./YelHodlStrategy.sol";

contract YelHodlStrategyMainnet_iFARM is YelHodlStrategy {

  address public ifarm_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0x1571eD0bed4D987fe2b498DdBaE7DFA19519F651);
    address yel = address(0x7815bDa662050D84718B988735218CFfd32f75ea);
    YelHodlStrategy.initializeMasterChefHodlStrategy(
      _storage,
      underlying,
      _vault,
      address(0x5dD8532613B9a6162BA795208D1A01613df26dc5), // master chef contract
      yel,
      0,  // Pool id
      address(0x0000000000000000000000000000000000000000), // manually set it later
      address(0x0000000000000000000000000000000000000000) // manually set it later
    );
  }
}
