pragma solidity 0.5.16;

interface INoMintRewardPool {
    function withdraw(uint) external;
    function getReward() external;
    function stake(uint) external;
    function balanceOf(address) external view returns (uint256);
    function earned(address account) external view returns (uint256);
    function exit() external;

    function rewardDistribution() external view returns (address);
    function lpToken() external view returns(address);
    function rewardToken() external view returns(address);

    // only owner
    function setRewardDistribution(address _rewardDistributor) external;
    function transferOwnership(address _owner) external;
    function notifyRewardAmount(uint256 _reward) external;
}
