pragma solidity 0.5.16;

import "./CRVStrategyAnkrETH.sol";


/**
* This strategy is for the ankrCRV vault, i.e., the underlying token is ankrCRV. It is not to accept
* stable coins. It will farm the CRV crop. For liquidation, it swaps CRV into ETH and uses ETH
* to produce ankrCRV.
*/
contract CRVStrategyAnkrETHMainnet is CRVStrategyAnkrETH {

  address public ankrCRV = address(0xaA17A236F2bAdc98DDc0Cf999AbB47D47Fc0A6Cf);

  constructor(
    address _storage,
    address _vault
  ) CRVStrategyAnkrETH (
    _storage,
    _vault,
    address(0xaA17A236F2bAdc98DDc0Cf999AbB47D47Fc0A6Cf), // ankrCRV underlying
    address(0x6d10ed2cF043E6fcf51A0e7b4C2Af3Fa06695707), // _gauge
    address(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0), // _mintr
    address(0xD533a949740bb3306d119CC777fa900bA034cd52), // _crv
    address(0xE0aD1806Fd3E7edF6FF52Fdb822432e847411033), // _onx
    address(0x8290333ceF9e6D528dD5618Fb97a76f268f3EDD4), // _ankr
    address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), // _weth
    address(0xA96A65c051bF88B4095Ee1f2451C2A9d43F53Ae2), // depositAnkrETH
    address(0x7882172921E99d590E097cD600554339fBDBc480)  // _universalLiquidatorRegistry
  ) public {
  }
}
