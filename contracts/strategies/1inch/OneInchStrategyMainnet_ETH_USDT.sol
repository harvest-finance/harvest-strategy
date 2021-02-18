pragma solidity 0.5.16;

import "./OneInchStrategy_ETH_X.sol";


/**
* This strategy is for the ETH/USDT LP token on 1inch
*/
contract OneInchStrategy_ETH_USDT is OneInchStrategy_ETH_X {

  address public usdt = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);

  constructor(
    address _storage,
    address _vault
  ) OneInchStrategy_ETH_X (
    _storage,
    _vault,
    address(0xbBa17b81aB4193455Be10741512d0E71520F43cB), // underlying
    address(0xE22f6A5dd9e491dFAB49faeFdb32d01AaF99703e), // pool
    address(0x0EF1B8a0E726Fc3948E15b23993015eB1627f210)  // oneInchEthLP
  ) public {
    require(token1 == usdt, "token1 mismatch");
  }
}
