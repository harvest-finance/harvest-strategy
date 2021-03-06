pragma solidity 0.5.16;
import "./IdleFinanceStrategyV3.sol";

/**
* RA = Risk-adjusted (__idleUnderlying is the difference)
*/

contract IdleStrategyUSDC_RA_MainnetV3 is IdleFinanceStrategyV3 {

  // token addresses
  address constant public __weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address constant public __usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  address constant public __uniswap = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address constant public __idleUnderlying= address(0x3391bc034f2935eF0E1e41619445F998b2680D35);
  address constant public __comp = address(0xc00e94Cb662C3520282E6f5717214004A7f26888);
  address constant public __idle = address(0x875773784Af8135eA0ef43b5a374AaD105c5D39e);

  constructor(
    address _storage,
    address _vault
  )
  IdleFinanceStrategyV3(
    _storage,
    __usdc,
    __idleUnderlying,
    _vault,
    __comp,
    __idle,
    __weth,
    __uniswap
  )
  public {
  }
}
