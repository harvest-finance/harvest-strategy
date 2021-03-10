pragma solidity 0.5.16;

import "./XSushiStrategyUpgradeable.sol";

contract XSushiStrategyUpgradeableMainnet is XSushiStrategyUpgradeable {

  address public xSushiStrategyUpgradeableMainnet; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address __sushi = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    address __xsushi = address(0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272);
    address __lendingPoolProvider = address(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
    address __protocolDataProvider = address(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);
    uint256 __defaultCap = 0;
    XSushiStrategyUpgradeable.initializeStrategy(
      _storage, __sushi, _vault, __xsushi, __lendingPoolProvider, __protocolDataProvider, __defaultCap
    );
  }
}