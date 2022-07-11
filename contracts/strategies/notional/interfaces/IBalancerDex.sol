pragma solidity 0.5.16;

interface IBalancerDex {

  function changeVault (address _newVault) external;
  function changePoolId (address _token0, address _token1, bytes32 _poolId) external;
  function doSwap(
    uint256 amountIn,
    uint256 minAmountOut,
    address spender,
    address target,
    address[] calldata path
  ) external returns(uint256);
}
