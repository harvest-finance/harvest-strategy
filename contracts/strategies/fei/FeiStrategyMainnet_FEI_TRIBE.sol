pragma solidity 0.5.16;

import "../../base/snx-base/SNXRewardUniLPStrategy.sol";

contract FeiStrategyMainnet_FEI_TRIBE is SNXRewardUniLPStrategy {

  address public tribe = address(0xc7283b66Eb1EB5FB86327f08e1B5816b0720212B);
  address public fei = address(0x956F47F50A910163D8BF957Cf5846D573E7f87CA);
  address public underlying = address(0x9928e4046d7c6513326cCeA028cD3e7a91c7590A);
  address public tribeRewardPool = address(0x18305DaAe09Ea2F4D51fAa33318be5978D251aBd);
  address public constant uniswapRouterAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor(
    address _storage,
    address _vault
  )
  SNXRewardUniLPStrategy(_storage, underlying, _vault, tribeRewardPool, tribe, uniswapRouterAddress)
  public {
    uniswapRoutes[fei] = [tribe, fei];
    uniswapRoutes[tribe] = [tribe];
  }
}
