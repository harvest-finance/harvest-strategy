pragma solidity 0.5.16;

import "./OneInchStrategy_ONEINCH_X.sol";


/**
* This strategy is for the 1INCH/USDCLP token on 1inch
*/
contract OneInchStrategyMainnet_ONEINCH_USDC is OneInchStrategy_ONEINCH_X {

  address public usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

  constructor(
    address _storage,
    address _vault
  ) OneInchStrategy_ONEINCH_X (
    _storage,
    _vault,
    address(0x69AB07348F51c639eF81d7991692f0049b10D522), // underlying
    address(0x1055f60Bbf27D233C4E34D2E03e35567427415Fa) // pool
  ) public {
    require(token1 == usdc, "token1 mismatch");
  }
}
