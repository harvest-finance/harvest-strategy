pragma solidity 0.5.16;
import "./IdleFinanceStrategy.sol";

/**
* Adds the mainnet addresses to the PickleStrategy3Pool
*/
contract IdleStrategyUSDTMainnet is IdleFinanceStrategy {

  // token addresses
  address constant public __usdt = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
  address constant public __idleUnderlying= address(0xF34842d05A1c888Ca02769A633DF37177415C2f8);
  address constant public __comp = address(0xc00e94Cb662C3520282E6f5717214004A7f26888);
  address constant public __idle = address(0x875773784Af8135eA0ef43b5a374AaD105c5D39e);
  address constant public __stkaave = address(0x4da27a545c0c5B758a6BA100e3a049001de870f5);
  address constant public __aave = address(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);

  constructor(
    address _storage,
    address _vault
  )
  IdleFinanceStrategy(
    _storage,
    __usdt,
    __idleUnderlying,
    _vault,
    __stkaave
  )
  public {
    rewardTokens = [__comp, __idle, __aave];
    reward2WETH[__comp] = [__comp, weth];
    reward2WETH[__idle] = [__idle, weth];
    reward2WETH[__aave] = [__aave, weth];
    WETH2underlying = [weth, __usdt];
    sell[__comp] = true;
    sell[__idle] = true;
    sell[__aave] = true;
    useUni[__comp] = false;
    useUni[__idle] = false;
    useUni[__aave] = false;
    useUni[__usdt] = false;
    allowedRewardClaimable = true;
  }
}
