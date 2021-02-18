pragma solidity 0.5.16;

import "./OneInchStrategy_ETH_X.sol";


/**
* This strategy is for the ETH/WBTC LP token on 1inch
*/
contract OneInchStrategy_ETH_WBTC is OneInchStrategy_ETH_X {

  address public wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

  constructor(
    address _storage,
    address _vault
  ) OneInchStrategy_ETH_X (
    _storage,
    _vault,
    address(0x6a11F3E5a01D129e566d783A7b6E8862bFD66CcA), // underlying
    address(0x2eDe375d73D81dBd19ef58A75ba359Dd28d25De8), // pool
    address(0x0EF1B8a0E726Fc3948E15b23993015eB1627f210)  // oneInchEthLP
  ) public {
    require(token1 == wbtc, "token1 mismatch");
  }
}
