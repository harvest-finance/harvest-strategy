pragma solidity 0.5.16;

interface IPercentageFeeModel { 
    function owner() external view returns(address);
 
    // onlyOwner
    function overrideEarlyWithdrawFeeForDeposit(
        address pool,
        uint64 depositID,
        uint256 newFee
    ) external;

    function getEarlyWithdrawFeeAmount(
        address pool,
        uint64 depositID,
        uint256 withdrawnDepositAmount
    ) external view returns (uint256 feeAmount);
}