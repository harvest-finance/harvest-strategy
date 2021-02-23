pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardUniLPStrategy.sol";

contract KlondikeStrategyMainnet_WBTC_KLON is SNXRewardUniLPStrategy {

  address public wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
  address public wbtc_klon = address(0x734e48A1FfEA1cdF4F5172210C322f3990d6D760);
  address public klon = address(0xB97D5cF2864FB0D08b34a484FF48d5492B2324A0);
  address public WBTCKLONRewardPool = address(0xC3503F004aa2cd689803A0D4E6ed07E8949525Fd);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardUniLPStrategy(_storage, wbtc_klon, _vault, WBTCKLONRewardPool, klon, uniswapRouterAddress)
  public {
    require(IVault(_vault).underlying() == wbtc_klon, "Underlying mismatch");
    // token0 is DAI, token1 is BSG
    uniswapRoutes[uniLPComponentToken0] = [klon, wbtc];
    uniswapRoutes[uniLPComponentToken1] = [klon];
  }
}
