pragma solidity 0.5.16;

import "./IDInterest.sol";

interface IDInterestLens {
  
  /**
        @notice Computes the amount of stablecoins that can be withdrawn
                by burning `virtualTokenAmount` virtual tokens from the deposit
                with ID `depositID` at time `timestamp`.
        @dev The queried timestamp should >= the deposit's lastTopupTimestamp, since
             the information before this time is forgotten.
        @param pool The DInterest pool
        @param depositID The ID of the deposit
        @param virtualTokenAmount The amount of virtual tokens to burn
        @return withdrawableAmount The amount of stablecoins (after fee) that can be withdrawn
        @return feeAmount The amount of fees that will be given to the beneficiary
     */
    function withdrawableAmountOfDeposit(
        IDInterest pool,
        uint64 depositID,
        uint256 virtualTokenAmount
    ) external view returns (uint256 withdrawableAmount, uint256 feeAmount);

}