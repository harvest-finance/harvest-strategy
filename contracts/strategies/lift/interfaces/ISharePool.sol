pragma solidity 0.5.16;

interface ISharePool {
    function withdraw(uint) external;
    function stake(uint) external;
    function stakeInBoardroom() external;
    function balanceOf(address) external view returns (uint256);
    function earned(address account) external view returns (uint256);
    function exit() external;
    function boardroom() external view returns(address);
}
