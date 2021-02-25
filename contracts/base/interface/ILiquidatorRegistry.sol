// SPDX-License-Identifier: MIT
pragma solidity 0.5.16;

interface ILiquidatorRegistry {

  function universalLiquidator() external view returns(address);

  function setUniversalLiquidator(address _ul) external;

  function getPath(
    bytes32 dex,
    address inputToken,
    address outputToken
  ) external view returns(address[] memory);

  function setPath(
    bytes32 dex,
    address inputToken,
    address outputToken,
    address[] calldata path
  ) external;
}
