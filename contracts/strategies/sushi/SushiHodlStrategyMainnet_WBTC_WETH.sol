pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefHodlStrategy.sol";

contract SushiHodlStrategyMainnet_WBTC_WETH is MasterChefHodlStrategy {

  address public wbtc_weth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xCEfF51756c56CeFFCA006cD410B03FFC46dd3a58);
    address sushi = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    MasterChefHodlStrategy.initializeMasterChefHodlStrategy(
      _storage,
      underlying,
      _vault,
      address(0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd), // master chef contract
      sushi,
      21,  // Pool id
      address(0x274AA8B58E8C57C4e347C8768ed853Eb6D375b48), // Sushi hodlVault fsushi
      address(0x0000000000000000000000000000000000000000) // manually set it later
    );
  }
}
