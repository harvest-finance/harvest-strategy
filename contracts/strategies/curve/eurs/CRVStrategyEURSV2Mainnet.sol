pragma solidity 0.5.16;

import "./CRVStrategyEURSV2.sol";


/**
* This strategy is for the crvEURS vault, i.e., the underlying token is crvEURS. It is not to accept
* stable coins. It will farm the CRV crop. For liquidation, it swaps CRV into DAI and uses DAI
* to produce crvEURS.
*/
contract CRVStrategyEURSV2Mainnet is CRVStrategyEURSV2 {

  address public crvEURS = address(0x194eBd173F6cDacE046C53eACcE9B953F28411d1);

  constructor(
    address _storage,
    address _vault
  ) CRVStrategyEURSV2 (
    _storage,
    _vault,
    address(0x194eBd173F6cDacE046C53eACcE9B953F28411d1), // crvEURS underlying
    address(0x90Bb609649E0451E5aD952683D64BD2d1f245840), // _gauge
    address(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0), // _mintr
    address(0xD533a949740bb3306d119CC777fa900bA034cd52), // _crv
    address(0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F), // _snx
    address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), // _weth
    address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48), // _usdc
    address(0xdB25f211AB05b1c97D595516F45794528a807ad8), // _eurs
    address(0x0Ce6a5fF5217e38315f87032CF90686C96627CAA), // depositEURS
    address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D) // _uniswap
  ) public {
  }
}
