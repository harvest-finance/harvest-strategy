pragma solidity 0.5.16;

interface IcvxRewardPool {
    function balanceOf(address account) external view returns(uint256 amount);
    function stakingToken() external view returns (address _stakingToken);
    function getReward(address, bool, bool) external;
    function stake(uint256 _amount) external;
    function stakeAll() external;
    function withdraw(uint256 amount, bool claim) external;
    function withdrawAll(bool claim) external;
}
