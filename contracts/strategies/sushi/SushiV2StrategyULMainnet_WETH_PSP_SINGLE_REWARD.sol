pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefV2StrategyUL.sol";

contract SushiV2StrategyULMainnet_WETH_PSP_SINGLE_REWARD_TOKEN is MasterChefV2StrategyUL {
  address private sushi_spell_weth; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(address __storage, address _vault)
    public
    initializer
  {
    // SushiSwap ETH/PSP LP (SLP) https://etherscan.io/address/0x458ae80894a0924ac763c034977e330c565f1687
    address underlying_ = address(
      0x458ae80894A0924Ac763C034977e330c565F1687
    );
    address sushi = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address psp = address(0xcAfE001067cDEF266AfB7Eb5A286dCFD277f3dE5);

    address masterchefV2 = address(
      0xEF0881eC094552b2e128Cf945EF17a6752B4Ec5d
    );
    address sushiswapRouterV2 = address(
      0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F
    );

    uint256 poolId_ = 31;
    bytes32 sushiDex = bytes32(uint256(keccak256("sushi")));

    MasterChefV2StrategyUL.initializeBaseStrategy({
      __storage: __storage,
      _underlying: underlying_,
      _vault: _vault,
      _rewardPool: masterchefV2,
      _rewardToken: sushi,
      _poolID: poolId_,
      _routerV2: sushiswapRouterV2
    });

    //sell rewardToken(=SUSHI) for WETH and PSP to be able to add liquidity to the pool
    storedLiquidationPaths[sushi][psp] = [sushi, weth, psp];
    storedLiquidationDexes[sushi][psp] = [sushiDex, sushiDex];

    storedLiquidationPaths[sushi][weth] = [sushi, weth];
    storedLiquidationDexes[sushi][weth] = [sushiDex];
  }
}
