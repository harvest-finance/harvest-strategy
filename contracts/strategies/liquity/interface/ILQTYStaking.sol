pragma solidity 0.5.16;

interface ILQTYStaking {
    function stakes(address _account) external view returns (uint256);

    function stake(uint256 _LQTYamount) external;

    function unstake(uint256 _LQTYamount) external;
}
