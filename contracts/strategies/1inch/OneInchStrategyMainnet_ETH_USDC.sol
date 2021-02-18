pragma solidity 0.5.16;

import "./OneInchStrategy_ETH_X.sol";


/**
* This strategy is for the ETH/USDC LP token on 1inch
*/
contract OneInchStrategy_ETH_USDC is OneInchStrategy_ETH_X {

  address public usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

  constructor(
    address _storage,
    address _vault
  ) OneInchStrategy_ETH_X (
    _storage,
    _vault,
    address(0xb4dB55a20E0624eDD82A0Cf356e3488B4669BD27), // underlying
    address(0xc7c42eccAc0D4Bb790a32Bc86519aC362e01d388), // pool
    address(0x0EF1B8a0E726Fc3948E15b23993015eB1627f210)  // oneInchEthLP
  ) public {
    require(token1 == usdc, "token1 mismatch");
  }
}
