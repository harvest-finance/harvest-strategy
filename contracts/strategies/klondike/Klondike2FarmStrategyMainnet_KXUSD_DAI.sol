pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXReward2FarmStrategyUL.sol";

contract Klondike2FarmStrategyMainnet_KXUSD_DAI is SNXReward2FarmStrategyUL {

  address public dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address public kxusd_dai = address(0x672C973155c46Fc264c077a41218Ddc397bB7532);
  address public kxusd = address(0x43244C686a014C49D3D5B8c4b20b4e3faB0cbDA7);
  address public klonx = address(0xbf15797BB5E47F6fB094A4abDB2cfC43F77179Ef);
  address public KXUSDDAIRewardPool = address(0xE301F632E573A3F8bd06fe623E4440560ab08692);
  address public constant universalLiquidatorRegistry = address(0x7882172921E99d590E097cD600554339fBDBc480);
  address public constant farm = address(0xa0246c9032bC3A600820415aE600c6388619A14D);

  constructor(
    address _storage,
    address _vault,
    address _distributionPool
  )
  SNXReward2FarmStrategyUL(_storage, kxusd_dai, _vault, KXUSDDAIRewardPool, klonx, universalLiquidatorRegistry, farm, _distributionPool)
  public {
    require(IVault(_vault).underlying() == kxusd_dai, "Underlying mismatch");
    liquidationPath = [klonx, farm];
    liquidationDexes.push(bytes32(uint256(keccak256("uni"))));
  }
}
