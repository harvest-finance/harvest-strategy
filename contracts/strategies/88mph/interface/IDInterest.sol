pragma solidity 0.5.16;

interface IDInterest {

    /**
        @notice Create a deposit using `depositAmount` stablecoin that matures at timestamp `maturationTimestamp`.
        @dev The ERC-721 NFT representing deposit ownership is given to msg.sender
        @param depositAmount The amount of deposit, in stablecoin
        @param maturationTimestamp The Unix timestamp of maturation, in seconds
        @param minimumInterestAmount If the interest amount is less than this, revert
        @param uri The metadata URI for the minted NFT
        @return depositID The ID of the created deposit
        @return interestAmount The amount of fixed-rate interest
     */
    function deposit(
        uint256 depositAmount,
        uint64 maturationTimestamp,
        uint256 minimumInterestAmount,
        string uri
    ) external returns (uint64 depositID, uint256 interestAmount);

     /**
        @notice Add `depositAmount` stablecoin to the existing deposit with ID `depositID`.
        @dev The interest rate for the topped up funds will be the current oracle rate.
        @param depositID The deposit to top up
        @param depositAmount The amount to top up, in stablecoin
        @return interestAmount The amount of interest that will be earned by the topped up funds at maturation
     */
    function topupDeposit(uint64 depositID, uint256 depositAmount)
        external
        returns (uint256 interestAmount);



    /**
        @notice Withdraw all funds from deposit with ID `depositID` and use them
                to create a new deposit that matures at time `maturationTimestamp`
        @param depositID The deposit to roll over
        @param maturationTimestamp The Unix timestamp of the new deposit, in seconds
        @return newDepositID The ID of the new deposit
     */
    function rolloverDeposit(uint64 depositID, uint64 maturationTimestamp)
        external
        returns (uint256 newDepositID, uint256 interestAmount);


    /**
        @notice Withdraws funds from the deposit with ID `depositID`.
        @dev Virtual tokens behave like zero coupon bonds, after maturation withdrawing 1 virtual token
             yields 1 stablecoin. The total supply is given by deposit.virtualTokenTotalSupply
        @param depositID the deposit to withdraw from
        @param virtualTokenAmount the amount of virtual tokens to withdraw
        @param early True if intend to withdraw before maturation, false otherwise
        @return withdrawnStablecoinAmount the amount of stablecoins withdrawn
     */
    function withdraw(
        uint64 depositID,
        uint256 virtualTokenAmount,
        bool early
    ) external returns (uint256 withdrawnStablecoinAmount);

    /**
        @notice Returns the Deposit struct associated with the deposit with ID
                `depositID`.
        @param depositID The ID of the deposit
        @return The deposit struct
     */
    function getDeposit(uint64 depositID)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint64, uint64);

    // User deposit data
    // Each deposit has an ID used in the depositNFT, which is equal to its index in `deposits` plus 1
    // struct Deposit {
    //     uint256 virtualTokenTotalSupply; // depositAmount + interestAmount, behaves like a zero coupon bond
    //     uint256 interestRate; // interestAmount = interestRate * depositAmount
    //     uint256 feeRate; // feeAmount = feeRate * depositAmount
    //     uint256 averageRecordedIncomeIndex; // Average income index at time of deposit, used for computing deposit surplus
    //     uint64 maturationTimestamp; // Unix timestamp after which the deposit may be withdrawn, in seconds
    //     uint64 fundingID; // The ID of the associated Funding struct. 0 if not funded.
    // }
}