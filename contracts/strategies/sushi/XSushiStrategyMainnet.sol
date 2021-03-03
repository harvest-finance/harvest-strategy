pragma solidity 0.5.16;

import "./XSushiStrategy.sol";

contract XSushiStrategyMainnet is XSushiStrategy {

  // token addresses
  address public __sushi = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
  address public __xsushi = address(0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272);
  address public __lendingPoolProvider = address(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
  address public __protocolDataProvider = address(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);
  uint256 public __defaultCap = 0;

  constructor(
    address _storage,
    address _vault
  ) XSushiStrategy(_storage, _vault, __sushi, __xsushi, __lendingPoolProvider, __protocolDataProvider, __defaultCap) public {}
}
