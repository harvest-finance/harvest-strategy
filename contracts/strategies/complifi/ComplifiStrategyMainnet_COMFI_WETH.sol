pragma solidity 0.5.16;

import "./ComplifiStrategy.sol";

contract ComplifiStrategyMainnet_COMFI_WETH is ComplifiStrategy {

  address public comfi_weth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xe9C966bc01b4f14c0433800eFbffef4F81540A97);
    address comfi = address(0x752Efadc0a7E05ad1BCCcDA22c141D01a75EF1e4);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ComplifiStrategy.initializeStrategy(
      _storage,
      underlying,
      _vault,
      address(0x8a5827Ad1f28d3f397B748CE89895e437b8ef90D), // master chef contract
      comfi,
      12,  // Pool id
      true, // is LP asset
      true // true = use Uniswap for liquidating
    );
    // comfi is token0, weth is token1
    uniswapRoutes[weth] = [comfi, weth];
  }
}
