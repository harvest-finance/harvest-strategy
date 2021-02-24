pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardUniLPStrategy.sol";

contract KlondikeStrategyMainnet_WBTC_KBTC is SNXRewardUniLPStrategy {

  address public wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
  address public wbtc_kbtc = address(0x1F3D61248EC81542889535595903078109707941);
  address public kbtc = address(0xE6C3502997f97F9BDe34CB165fBce191065E068f);
  address public klon = address(0xB97D5cF2864FB0D08b34a484FF48d5492B2324A0);
  address public WBTCKBTCRewardPool = address(0xDE8fBa1447f7c29F31Bd4aa0b9b1b51Eb6348148);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardUniLPStrategy(_storage, wbtc_kbtc, _vault, WBTCKBTCRewardPool, klon, uniswapRouterAddress)
  public {
    require(IVault(_vault).underlying() == wbtc_kbtc, "Underlying mismatch");
    // token0 is DAI, token1 is BSG
    uniswapRoutes[uniLPComponentToken0] = [klon, wbtc];
    uniswapRoutes[uniLPComponentToken1] = [klon, wbtc, kbtc];
  }
}
