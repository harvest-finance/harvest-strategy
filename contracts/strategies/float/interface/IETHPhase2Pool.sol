pragma solidity 0.5.16;

interface IETHPhase2Pool {
    function withdraw(uint) external;
    function getReward() external;
    function stake(uint) external payable;
    function balanceOf(address) external view returns (uint256);
    function earned(address account) external view returns (uint256);
    function exit() external;
}
