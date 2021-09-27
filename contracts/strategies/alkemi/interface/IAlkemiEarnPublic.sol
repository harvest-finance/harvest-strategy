pragma solidity 0.5.16;

interface IAlkemiEarnPublic {
    function getSupplyBalance(address account, address asset) external view returns (uint256);
    function supply(address asset, uint256 amount) external payable;
    function withdraw(address asset, uint256 requestedAmount) external;
}
