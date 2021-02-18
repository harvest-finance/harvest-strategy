pragma solidity 0.5.16;

contract IRewardDistributionSwitcher {

  function switchingAllowed(address) external returns(bool);
  function returnOwnership(address poolAddr) external;
  function enableSwitchers(address[] calldata switchers) external;
  function setSwithcer(address switcher, bool allowed) external;
  function setPoolRewardDistribution(address poolAddr, address newRewardDistributor) external;

}
