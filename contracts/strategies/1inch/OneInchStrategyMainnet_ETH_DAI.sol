pragma solidity 0.5.16;

import "./OneInchStrategy_ETH_X.sol";


/**
* This strategy is for the ETH/DAI LP token on 1inch
*/
contract OneInchStrategy_ETH_DAI is OneInchStrategy_ETH_X {

  address public dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);

  constructor(
    address _storage,
    address _vault
  ) OneInchStrategy_ETH_X (
    _storage,
    _vault,
    address(0x7566126f2fD0f2Dddae01Bb8A6EA49b760383D5A), // underlying
    address(0xCa6E3EBF4Ac8c3E84BCCDF5Cd89aece74D69F2a7), // pool
    address(0x0EF1B8a0E726Fc3948E15b23993015eB1627f210)  // oneInchEthLP
  ) public {
    require(token1 == dai, "token1 mismatch");
  }
}
