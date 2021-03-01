pragma solidity 0.5.16;

import "./CRVStrategyLINK.sol";


/**
* This strategy is for the crvEURS vault, i.e., the underlying token is crvEURS. It is not to accept
* stable coins. It will farm the CRV crop. For liquidation, it swaps CRV into DAI and uses DAI
* to produce crvEURS.
*/
contract CRVStrategyLINKMainnet is CRVStrategyLINK {

  address public crvLINK = address(0xcee60cFa923170e4f8204AE08B4fA6A3F5656F3a);

  constructor(
    address _storage,
    address _vault
  ) CRVStrategyLINK (
    _storage,
    _vault,
    address(0xcee60cFa923170e4f8204AE08B4fA6A3F5656F3a), // crvLINK underlying
    address(0xFD4D8a17df4C27c1dD245d153ccf4499e806C87D), // _gauge
    address(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0), // _mintr
    address(0xD533a949740bb3306d119CC777fa900bA034cd52), // _crv
    address(0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F), // _snx
    address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), // _weth
    address(0x514910771AF9Ca656af840dff83E8264EcF986CA), // _link
    address(0xF178C0b5Bb7e7aBF4e12A4838C7b7c5bA2C623c0), // depositLINK
    address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D) // _uniswap
  ) public {
  }
}
