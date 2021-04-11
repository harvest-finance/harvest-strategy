pragma solidity 0.5.16;

import "../../base/snx-base/interfaces/SNXRewardInterface.sol";
import "../../base/snx-base/SNXRewardUniLPStrategy.sol";

contract IndexStrategyMainnet_MVI_ETH is SNXRewardUniLPStrategy {

  address public mvi = address(0x72e364F2ABdC788b7E918bc238B21f109Cd634D7);
  address public mvi_weth = address(0x4d3C5dB2C68f6859e0Cd05D080979f597DD64bff);
  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public index = address(0x0954906da0Bf32d5479e25f46056d22f08464cab);
  address public MVIETHRewardPool = address(0x5bC4249641B4bf4E37EF513F3Fa5C63ECAB34881);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardUniLPStrategy(_storage, mvi_weth, _vault, MVIETHRewardPool, index, uniswapRouterAddress)
  public {
    require(IVault(_vault).underlying() == mvi_weth, "Underlying mismatch");
    // token0 is MVI, token1 is WETH
    uniswapRoutes[uniLPComponentToken0] = [index, weth, mvi];
    uniswapRoutes[uniLPComponentToken1] = [index, weth];
  }
}
