pragma solidity 0.5.16;

import "./ComplifiDerivStrategy.sol";

contract ComplifiDerivStrategyMainnet_UNI5x is ComplifiDerivStrategy {

  address public uni5x_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xF9444D2411669E47B1e46760d85C45EAc9694884);
    address usdcVault = address(0xd498bF281262e04b0Dc8A1c6D14877Cee46AAAAE);
    address proxy = address(0xdaEcc0941a2e68cDb8085D071A468BB05CBD235D);
    address comfi = address(0x752Efadc0a7E05ad1BCCcDA22c141D01a75EF1e4);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ComplifiDerivStrategy.initializeStrategy(
      _storage,
      underlying,
      _vault,
      address(0x8a5827Ad1f28d3f397B748CE89895e437b8ef90D), // master chef contract
      comfi,
      usdcVault,
      proxy
    );
    // comfi is token0, weth is token1
    liquidationPath = [comfi, weth, usdc];
  }
}
