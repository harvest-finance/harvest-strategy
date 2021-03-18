pragma solidity 0.5.16;

import "./OneInchStrategy_ETH_X_V2.sol";


/**
* This strategy is for the ETH/DAI LP token on 1inch
*/
contract OneInchStrategy_ETH_ONEINCH is OneInchStrategy_ETH_X_V2 {

  address public oneInch = address(0x111111111117dC0aa78b770fA6A738034120C302);

  constructor(
    address _storage,
    address _vault
  ) OneInchStrategy_ETH_X_V2 (
    _storage,
    _vault,
    address(0x0EF1B8a0E726Fc3948E15b23993015eB1627f210), // underlying
    address(0xE65184b402376703Adc27A7d7e0e8D35A264A240), // pool
    address(0x0EF1B8a0E726Fc3948E15b23993015eB1627f210)  // oneInchEthLP
  ) public {
    require(token1 == oneInch, "token1 mismatch");
  }
}
