pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXReward2FarmStrategyUL.sol";

contract MirrorMainnet_mTWTR_UST is SNXReward2FarmStrategyUL {

  address public ust = address(0xa47c8bf37f92aBed4A126BDA807A7b7498661acD);
  address public mtwtr_ust = address(0x34856be886A2dBa5F7c38c4df7FD86869aB08040);
  address public mtwtr = address(0xEdb0414627E6f1e3F082DE65cD4F9C693D78CCA9);
  address public mir = address(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public mTWTRUSTRewardPool = address(0x99d737ab0df10cdC99c6f64D0384ACd5C03AEF7F);
  address public constant universalLiquidatorRegistry = address(0x7882172921E99d590E097cD600554339fBDBc480);
  address public constant farm = address(0xa0246c9032bC3A600820415aE600c6388619A14D);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXReward2FarmStrategyUL(_storage, mtwtr_ust, _vault, mTWTRUSTRewardPool, mir, universalLiquidatorRegistry, farm, _distributionPool)
  public {
    require(IVault(_vault).underlying() == mtwtr_ust, "Underlying mismatch");
    liquidationPath = [mir, farm];
    liquidationDexes.push(bytes32(uint256(keccak256("uni"))));
    allowedRewardClaimable = true;
  }
}
