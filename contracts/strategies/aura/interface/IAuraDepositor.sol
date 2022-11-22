pragma solidity 0.5.16;

interface IAuraDepositor{
    function deposit(uint256, bool) external;
    function lockIncentive() external view returns(uint256);
}