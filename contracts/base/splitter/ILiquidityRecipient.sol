pragma solidity 0.5.16;

interface ILiquidityRecipient {
  function takeLoan(uint256 amount) external;
  function settleLoan() external;
  function wethOverdraft() external;
  function salvage(address recipient, address token, uint256 amount) external;
  function stake(address pool, uint256 amount) external;
  function unstake(address pool) external;
  function getReward(address pool) external;
}