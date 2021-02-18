pragma solidity 0.5.16;

import "./CRVStrategyOBTC.sol";


/**
* This strategy is for the crvOBTC vault, i.e., the underlying token is crvOBTC. It is not to accept
* stable coins. It will farm the CRV crop. For liquidation, it swaps CRV into DAI and uses DAI
* to produce crvOBTC.
*/
contract CRVStrategyOBTCMainnet is CRVStrategyOBTC {

  // for verification purposes, we need the bytecode of this Mainnet version to be different than the base
  bool public isCRVStrategyOBTCMainnet = true;

  constructor(
    address _storage,
    address _vault
  ) CRVStrategyOBTC (
    _storage,
    _vault,
    address(0x2fE94ea3d5d4a175184081439753DE15AeF9d614), // crvOBTC underlying
    address(0x11137B10C210b579405c21A07489e28F3c040AB1), // _gauge
    address(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0), // _mintr
    address(0xD533a949740bb3306d119CC777fa900bA034cd52), // _crv
    address(0x3c9d6c1C73b31c837832c72E04D3152f051fc1A9), // _bor
    address(0xd81dA8D904b52208541Bade1bD6595D8a251F8dd), // _curve's stableswap
    address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), // _weth
    address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599), // _wbtc
    address(0xd5BCf53e2C81e1991570f33Fa881c49EEa570C8D), // depositOBTC
    address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D), // _uniswap
    address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F) // _sushiswap
  ) public {
  }
}
