pragma solidity 0.5.16;

import "./Basis2FarmStrategyV3.sol";

contract Basis2FarmStrategyMainnet_DAI_BASV3 is Basis2FarmStrategyV3 {

  address public constant __dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address public __basv2 = address(0x106538CC16F938776c7c180186975BCA23875287);

  address public __dai_basv2 = address(0x3E78F2E7daDe07ea685F8612F00477FD97162F1e);
  address public constant __rewardPool = address(0x818F83333244bA4BB72Dab0b60b1901158402f2E);

  address public constant __universalLiquidatorRegistry = address(0x7882172921E99d590E097cD600554339fBDBc480);

  address public constant __farm = address(0xa0246c9032bC3A600820415aE600c6388619A14D);
  address public constant __weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant __notifyHelper = address(0xE20c31e3d08027F5AfACe84A3A46B7b3B165053c);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool,
    address _distributionSwitcher
  )
  Basis2FarmStrategyV3(
    _storage,
    __dai_basv2,
    _vault,
    __rewardPool,
    2, // pool ID
    __basv2,
    __universalLiquidatorRegistry,
    __farm,
    _distributionPool,
    _distributionSwitcher
  )
  public {
    require(IVault(_vault).underlying() == __dai_basv2, "Underlying mismatch");
    liquidationPath = [__basv2, farm];
    liquidationDexes.push(bytes32(uint256(keccak256("uni"))));
    defaultRewardDistribution = __notifyHelper;
  }
}
