pragma solidity 0.5.16;

interface IxMph {
     /**
        @notice Deposit MPH to get xMPH
        @dev The amount can't be 0
        @param _mphAmount The amount of MPH to deposit
        @return shareAmount The amount of xMPH minted
     */
    function deposit(uint256 _mphAmount) external returns (uint256 shareAmount);

    /**
        @notice Withdraw MPH using xMPH
        @dev The amount can't be 0
        @param _shareAmount The amount of xMPH to burn
        @return mphAmount The amount of MPH withdrawn
     */
    function withdraw(uint256 _shareAmount) external returns (uint256 mphAmount);

    /**
        @notice Compute the amount of MPH that can be withdrawn by burning
                1 xMPH. Increases linearly during a reward distribution period.
        @dev Initialized to be PRECISION (representing 1 MPH = 1 xMPH)
        @return The amount of MPH that can be withdrawn by burning
                1 xMPH
     */
    function getPricePerFullShare() external view returns (uint256);


    function balanceOf(address) external view returns (uint256);
}