pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategyWithBuyback.sol";

contract NFT20Strategy_ROPE is MasterChefStrategyWithBuyback {

  address public rope_eth_unused; // just a differentiator for the bytecode
  address public constant ropeEthLp = address(0x95ACF4ba2c53E31Db1459172332D52bAaC433bB3);
  address public constant masterChef = address(0x193b775aF4BF9E11656cA48724A710359446BF52);
  address public constant muse = address(0xB6Ca7399B4F9CA56FC27cBfF44F4d2e4Eef1fc81);
  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant rope = address(0xB3CDC594D8C8e8152d99F162cF8f9eDFdc0A80A2);

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault,
    address _distributionPool
  ) public initializer {
    uint256 poolId = 7;
    MasterChefStrategyWithBuyback.initializeBaseStrategy(
      _storage,
      ropeEthLp,
      _vault,
      masterChef,
      muse,
      poolId,
      true, // is LP asset
      true, // use Uniswap
      _distributionPool,
      0
    );
    uniswapRoutes[weth] = [muse, weth]; // swaps to weth
    uniswapRoutes[rope] = [muse, weth, rope];
    setSell(true);
    setSellFloor(1e16);
  }
}
