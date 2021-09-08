pragma solidity 0.5.16;

interface IStaking {
    function deposit(address token, uint256 amount) external;
    function withdraw(address token, uint256 amount) external;
    function emergencyWithdraw(address token) external;
    function balanceOf(address user, address token) external view returns(uint256);
    function getCurrentEpoch() external view returns(uint128);
    function epochIsInitialized(address token, uint128 epochId) external view returns(bool);
    function manualEpochInit(address[] calldata tokens, uint128 epochId) external;
}
