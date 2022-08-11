pragma solidity ^0.5.16;


interface IStargateFarmingPool {

    function pendingStargate(uint _poolId, address _user) external view returns (uint256);

    function poolInfo(
        uint _poolId
    ) external view returns (
        address lpToken,
        uint allocPoint,
        uint lastRewardBlock,
        uint accStargatePerShare
    );

    function userInfo(uint _poolId, address _user) external view returns (uint256 balance, uint256 rewardDebt);

    function deposit(uint _poolId, uint _amount) external;

    function withdraw(uint _poolId, uint _amount) external;
}