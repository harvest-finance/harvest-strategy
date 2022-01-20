pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefStrategyUL.sol";

contract SushiStrategyULMainnet_SUSHI_WETH is MasterChefStrategyUL {
  address public sushi_weth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(address __storage, address _vault)
    public
    initializer
  {
    // SushiSwap ETH/PSP LP (SLP) https://etherscan.io/address/0x458ae80894a0924ac763c034977e330c565f1687
    address underlying_ = address(
      0x795065dCc9f64b5614C407a6EFDC400DA6221FB0
    );
    address sushi = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address masterchefV1 = address(
      0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd
    );
    address sushiswapRouterV2 = address(
      0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F
    );

    uint256 poolId_ = 12;
    bytes32 sushiDex = bytes32(uint256(keccak256("sushi")));

    MasterChefStrategyUL.initializeBaseStrategy({
      __storage: __storage,
      _underlying: underlying_,
      _vault: _vault,
      _rewardPool: masterchefV1,
      _rewardToken: sushi,
      _poolID: poolId_,
      _routerV2: sushiswapRouterV2
    });

    //sell rewardToken(=SUSHI) for WETH
    storedLiquidationPaths[sushi][weth] = [sushi, weth];
    storedLiquidationDexes[sushi][weth] = [sushiDex];
  }
}
