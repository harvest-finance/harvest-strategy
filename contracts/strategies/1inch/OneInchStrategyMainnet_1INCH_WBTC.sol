pragma solidity 0.5.16;

import "./OneInchStrategy_1INCH_X.sol";


/**
* This strategy is for the 1INCH/WBTC LP token on 1inch
*/
contract OneInchStrategy_1INCH_WBTC is OneInchStrategy_1INCH_X {

  bool public unused_is_1inch;
  address public wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

  constructor(
    address _storage,
    address _vault
  ) OneInchStrategy_1INCH_X (
    _storage,
    _vault,
    address(0xE179d801E6882e628d6ce58b94b3C41E35C8518A), // underlying
    address(0x73f5E5260423A2742d9F8Ac49DeA6CB5eaec465e), // pool
    address(0x0EF1B8a0E726Fc3948E15b23993015eB1627f210)  // oneInchEthLP
  ) public {
    require(token1 == wbtc, "token1 mismatch");
  }
}
