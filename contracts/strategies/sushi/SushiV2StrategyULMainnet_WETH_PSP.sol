pragma solidity 0.5.16;

import "../../base/sushi-base/MasterChefV2StrategyULTwoRewardTokens.sol";

contract SushiV2StrategyULMainnet_WETH_PSP is
  MasterChefV2StrategyULTwoRewardTokens
{
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

    MasterChefV2StrategyULTwoRewardTokens.initializeBaseStrategy({
      __storage: __storage,
      _underlying: underlying_,
      _vault: _vault,
      _rewardPool: masterchefV2,
      _rewardToken: psp,
      _secondRewardToken: sushi,
      _poolID: poolId_,
      _routerV2: sushiswapRouterV2
    });

    // sell all secondRewardTokens(=$SUSHI) for PSP
    storedLiquidationPaths[sushi][psp] = [sushi, psp];
    storedLiquidationDexes[sushi][psp] = [sushiDex];

    // sell 50% of rewardToken(=$PSP) for WETH, s.t. we can add liquidity
    storedLiquidationPaths[psp][weth] = [psp, weth];
    storedLiquidationDexes[psp][weth] = [sushiDex];
  }
}
