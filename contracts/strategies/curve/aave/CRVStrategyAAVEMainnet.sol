pragma solidity 0.5.16;

import "./CRVStrategyAAVE.sol";


/**
* This strategy is for the crvAAVE vault, i.e., the underlying token is crvAAVE. It is not to accept
* stable coins. It will farm the CRV crop. For liquidation, it swaps CRV into DAI and uses DAI
* to produce crvAAVE.
*/
contract CRVStrategyAAVEMainnet is CRVStrategyAAVE {

  constructor(
    address _storage,
    address _vault
  ) CRVStrategyAAVE (
    _storage,
    _vault,
    address(0xFd2a8fA60Abd58Efe3EeE34dd494cD491dC14900), // crvAAVE underlying
    address(0xd662908ADA2Ea1916B3318327A97eB18aD588b5d), // _gauge
    address(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0), // _mintr
    address(0xD533a949740bb3306d119CC777fa900bA034cd52), // _crv
    address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), // _weth
    address(0x6B175474E89094C44Da98b954EedeAC495271d0F), // _dai
    address(0xDeBF20617708857ebe4F679508E7b7863a8A8EeE), // depositAAVE
    address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D) // _uniswap
  ) public {
  }
}
