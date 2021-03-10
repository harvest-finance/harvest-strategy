pragma solidity 0.5.16;

import "./CRVStrategyUSDP.sol";


/**
* This strategy is for the crvGUSD vault, i.e., the underlying token is crvGUSD. It is not to accept
* stable coins. It will farm the CRV crop. For liquidation, it swaps CRV into DAI and uses DAI
* to produce crvGUSD.
*/
contract CRVStrategyUSDPMainnet is CRVStrategyUSDP {

  constructor(
    address _storage,
    address _vault
  ) CRVStrategyUSDP (
    _storage,
    _vault,
    address(0x7Eb40E450b9655f4B3cC4259BCC731c63ff55ae6), // usdp3CRV underlying
    address(0x055be5DDB7A925BfEF3417FC157f53CA77cA7222), // _gauge
    address(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0), // _mintr
    address(0xD533a949740bb3306d119CC777fa900bA034cd52), // _crv
    address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), // _weth
    address(0x6B175474E89094C44Da98b954EedeAC495271d0F), // _dai
    address(0x3c8cAee4E09296800f8D29A68Fa3837e2dae4940), // depositUSDP
    address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D) // _uniswap
  ) public {
  }
}
