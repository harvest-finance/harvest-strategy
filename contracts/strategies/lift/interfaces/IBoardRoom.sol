pragma solidity 0.5.16;

interface IBoardRoom {
    function getStakedAmountsShare() external view returns(uint256[2][] memory);
    function getbalanceOfControl(address account) external view returns(uint256);
    function getbalanceOfShare(address account) external view returns(uint256);
    function earned(address account) external view returns(uint256);
    function claimReward() external;
    function stakeControl(uint256 amount) external;
    function stakeShare(uint256 amount) external;
    function withdrawControl(uint256 amount) external;
    function withdrawShare(uint256 stakedTimeStamp) external;
    function withdrawShareDontCallMeUnlessYouAreCertain() external;
    function control() external view returns(address);
}
