pragma solidity 0.5.16;
import "./IdleFinanceStrategyClaimable.sol";

/**
* Adds the mainnet addresses to the PickleStrategy3Pool
*/
contract IdleStrategyWBTCMainnet is IdleFinanceStrategyClaimable {

  // token addresses
  address constant public __weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address constant public __wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
  address constant public __uniswap = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address constant public __idleUnderlying= address(0x8C81121B15197fA0eEaEE1DC75533419DcfD3151);
  address constant public __comp = address(0xc00e94Cb662C3520282E6f5717214004A7f26888);
  address constant public __idle = address(0x875773784Af8135eA0ef43b5a374AaD105c5D39e);
  address constant public __stkaave = address(0x4da27a545c0c5B758a6BA100e3a049001de870f5);
  address constant public __aave = address(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);

  constructor(
    address _storage,
    address _vault
  )
  IdleFinanceStrategyClaimable(
    _storage,
    __wbtc,
    __idleUnderlying,
    _vault,
    __comp,
    __stkaave,
    __aave,
    __idle,
    __weth,
    __uniswap
  )
  public {
  }
}
