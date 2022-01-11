pragma solidity 0.5.16;

interface IStakingPool {
    function userInfo(address account) external view returns (uint256, uint256);
    function stakedToken() external view returns (address);
    function calculatePendingRewards(address user) external view returns (uint256);
    function harvest() external;
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function emergencyWithdraw() external;
}
