pragma solidity 0.5.16;

import "./CRVStrategySTETH.sol";


/**
* This strategy is for the crvSTETH vault, i.e., the underlying token is crvSTETH. It is not to accept
* stable coins. It will farm the CRV crop. For liquidation, it swaps CRV into DAI and uses DAI
* to produce crvSTETH.
*/
contract CRVStrategySTETHMainnet is CRVStrategySTETH {

  address public steth = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

  constructor(
    address _storage,
    address _vault
  ) CRVStrategySTETH (
    _storage,
    _vault,
    address(0x06325440D014e39736583c165C2963BA99fAf14E), // crvSTETH underlying
    address(0x182B723a58739a9c974cFDB385ceaDb237453c28), // _gauge
    address(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0), // _mintr
    address(0xD533a949740bb3306d119CC777fa900bA034cd52), // _crv
    address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), // _weth
    address(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32), // _lido
    address(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022), // depositSTETH
    address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D) // _uniswap
  ) public {
  }
}
