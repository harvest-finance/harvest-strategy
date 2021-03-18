pragma solidity 0.5.16;

import "./OneInchStrategy_ONEINCH_X.sol";


/**
* This strategy is for the 1INCH/WBTC LP token on 1inch
*/
contract OneInchStrategyMainnet_ONEINCH_WBTC is OneInchStrategy_ONEINCH_X {

  address public wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

  constructor(
    address _storage,
    address _vault
  ) OneInchStrategy_ONEINCH_X (
    _storage,
    _vault,
    address(0xE179d801E6882e628d6ce58b94b3C41E35C8518A), // underlying
    address(0x73f5E5260423A2742d9F8Ac49DeA6CB5eaec465e) // pool
  ) public {
    require(token1 == wbtc, "token1 mismatch");
  }
}
