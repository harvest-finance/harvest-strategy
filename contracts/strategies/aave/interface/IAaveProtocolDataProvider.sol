// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.5.16;

contract IAaveProtocolDataProvider {

  function getReserveTokensAddresses(address asset)
    external
    view
    returns (
      address aTokenAddress,
      address stableDebtTokenAddress,
      address variableDebtTokenAddress
    );

}
