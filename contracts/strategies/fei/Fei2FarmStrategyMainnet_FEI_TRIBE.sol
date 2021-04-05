pragma solidity 0.5.16;

import "../../base/snx-base/SNXReward2FarmStrategyUL.sol";

contract Fei2FarmStrategyMainnet_FEI_TRIBE is SNXReward2FarmStrategyUL {

  address public tribe = address(0xc7283b66Eb1EB5FB86327f08e1B5816b0720212B);
  address public fei_tribe = address(0x9928e4046d7c6513326cCeA028cD3e7a91c7590A);
  address public fei = address(0x956F47F50A910163D8BF957Cf5846D573E7f87CA);
  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public tribeRewardPool = address(0x18305DaAe09Ea2F4D51fAa33318be5978D251aBd);
  address public constant universalLiquidatorRegistry = address(0x7882172921E99d590E097cD600554339fBDBc480);
  address public constant farm = address(0xa0246c9032bC3A600820415aE600c6388619A14D);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXReward2FarmStrategyUL(_storage, fei_tribe, _vault, tribeRewardPool, tribe, universalLiquidatorRegistry, farm, _distributionPool)
  public {
    require(IVault(_vault).underlying() == fei_tribe, "Underlying mismatch");
    liquidationPath = [tribe, weth, farm];
    liquidationDexes.push(bytes32(uint256(keccak256("uni"))));
    liquidationDexes.push(bytes32(uint256(keccak256("uni"))));
  }
}
