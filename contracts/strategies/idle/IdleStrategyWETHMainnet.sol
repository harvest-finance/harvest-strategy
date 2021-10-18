pragma solidity 0.5.16;
import "./IdleFinanceStrategy.sol";

/**
* Adds the mainnet addresses to the PickleStrategy3Pool
*/
contract IdleStrategyWETHMainnet is IdleFinanceStrategy {

  // token addresses
  address constant public __idleUnderlying= address(0xC8E6CA6E96a326dC448307A5fDE90a0b21fd7f80);
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
    weth,
    __idleUnderlying,
    _vault,
    __stkaave
  )
  public {
    rewardTokens = [__comp, __idle, __aave];
    reward2WETH[__comp] = [__comp, weth];
    reward2WETH[__idle] = [__idle, weth];
    reward2WETH[__aave] = [__aave, weth];
    sell[__comp] = true;
    sell[__idle] = true;
    sell[__aave] = true;
    useUni[__comp] = false;
    useUni[__idle] = false;
    useUni[__aave] = false;
    useUni[weth] = false;
    allowedRewardClaimable = true;
  }
}
