pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategyWithBuyback.sol";

contract SushiBuybackStrategyMainnet_PERP_WETH is MasterChefStrategyWithBuyback {

  address public constant perpEthLp = address(0x8486c538DcBD6A707c5b3f730B6413286FE8c854);
  address public constant masterChef = address(0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd);
  address public constant sushi = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant perp = address(0xbC396689893D065F41bc2C6EcbeE5e0085233447);

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault,
    address _distributionPool
  ) public initializer {
    uint256 poolId = 156;
    MasterChefStrategyWithBuyback.initializeBaseStrategy(
      _storage,
      perpEthLp,
      _vault,
      masterChef,
      sushi,
      poolId,
      true, // is LP asset
      false, // use Uniswap
      _distributionPool,
      5000
    );
    uniswapRoutes[weth] = [sushi, weth]; // swaps to weth
    uniswapRoutes[perp] = [sushi, weth, perp];
    setSell(true);
  }
}
