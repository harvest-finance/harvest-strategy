// SPDX-License-Identifier: MIT
pragma solidity 0.5.16;

interface IOneInchLiquidator {
  function changeReferral(address newReferral) external;

  function doSwap(
    uint256 amountIn,
    uint256 minAmountOut,
    address spender,
    address target,
    address[] calldata path
  ) external;

  function changePool(
    address _token0,
    address _token1,
    address _pool
  ) external;

}
