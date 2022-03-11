pragma solidity 0.5.16;

interface IVesting {
    function depositIDToVestID(address pool, uint64 depositId) external returns (uint64);

    function withdraw(uint64 vestID)
        external
        returns (uint256 withdrawnAmount);

    function getVestWithdrawableAmount(uint64 vestID)
        external
        view
        returns (uint256);
}