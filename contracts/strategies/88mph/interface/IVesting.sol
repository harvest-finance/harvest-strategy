pragma solidity 0.5.16;

interface IVesting {
    function withdraw(uint64 vestID)
        external
        returns (uint256 withdrawnAmount);

    function multiWithdraw(uint64[] vestIDList) external;

    function getVestWithdrawableAmount(uint64 vestID)
        external
        view
        returns (uint256);
}