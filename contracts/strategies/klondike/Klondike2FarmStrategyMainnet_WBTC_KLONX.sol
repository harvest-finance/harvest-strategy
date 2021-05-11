pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXReward2FarmStrategyUL.sol";

contract Klondike2FarmStrategyMainnet_WBTC_KLONX is SNXReward2FarmStrategyUL {

  address public wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
  address public wbtc_klonx = address(0x69Cda6eDa9986f7fCa8A5dBa06c819B535F4Fc50);
  address public klonx = address(0xbf15797BB5E47F6fB094A4abDB2cfC43F77179Ef);
  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public WBTCKLONRewardPool = address(0x185bDc02aAFbEcDc8DC574e8319228B586764415);
  address public constant universalLiquidatorRegistry = address(0x7882172921E99d590E097cD600554339fBDBc480);
  address public constant farm = address(0xa0246c9032bC3A600820415aE600c6388619A14D);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXReward2FarmStrategyUL(_storage, wbtc_klonx, _vault, WBTCKLONRewardPool, klonx, universalLiquidatorRegistry, farm, _distributionPool)
  public {
    require(IVault(_vault).underlying() == wbtc_klonx, "Underlying mismatch");
    liquidationPath = [klonx, farm];
    liquidationDexes.push(bytes32(uint256(keccak256("uni"))));
    allowedRewardClaimable = true;
  }
}
