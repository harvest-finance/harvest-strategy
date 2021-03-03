pragma solidity 0.5.16;

interface SushiBar {
  function enter(uint256 _amount) external;
  function leave(uint256 _share) external;
}