pragma solidity 0.5.16;

contract IUpgradeableStrategy {
  function scheduleUpgrade(address impl) external;
  function upgrade() external;
}
