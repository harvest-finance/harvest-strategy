pragma solidity 0.5.16;

import "./CRVStrategyUST.sol";


/**
* This strategy is for the crvUST vault, i.e., the underlying token is crvUST. It is not to accept
* stable coins. It will farm the CRV crop. For liquidation, it swaps CRV into DAI and uses DAI
* to produce crvUST.
*/
contract CRVStrategyUSTMainnet is CRVStrategyUST {
  bool public isCRVStrategyUSTMainnet = true; // making the bytecode distinct
  constructor(
    address _storage,
    address _vault
  ) CRVStrategyUST (
    _storage,
    _vault,
    address(0x94e131324b6054c0D789b190b2dAC504e4361b53), // crvUST underlying
    address(0x3B7020743Bc2A4ca9EaF9D0722d42E20d6935855), // _gauge
    address(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0), // _mintr
    address(0xD533a949740bb3306d119CC777fa900bA034cd52), // _crv
    address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), // _weth
    address(0xdAC17F958D2ee523a2206206994597C13D831ec7), // _usdt
    address(0xB0a0716841F2Fc03fbA72A891B8Bb13584F52F2d), // depositUST
    address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D) // _uniswap
  ) public {
  }
}
