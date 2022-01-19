pragma solidity 0.5.16;

/**
 * Contract used for single asset LOOKS staking which rewards autocompounded LOOKS and 
 * not autocompounded WETH as part of the fee sharing model
 */
interface IFeeSharingSystem {
    // returns shares uint256, userRewardPerTokenPaid uint256, rewards uint256
    function userInfo(address account) external view returns (uint256, uint256, uint256);

    function rewardToken() external view returns (address);

    // Calculate pending rewards (WETH) for a user
    function calculatePendingRewards(address user) external view returns (uint256);

    // Harvest reward tokens that are pending
    function harvest() external;

    // Deposit staked tokens (and collect reward tokens if requested)
    function deposit(uint256 amount, bool claimRewardToken) external;

    // Withdraw staked tokens (and collect reward tokens if requested)
    function withdraw(uint256 amount, bool claimRewardToken) external;

    // Withdraw all staked tokens (and collect reward tokens if requested)
    function withdrawAll(bool claimRewardToken) external;
    
    // Calculate price of one share (in LOOKS token) Share price is expressed times 1e18
    function calculateSharePriceInLOOKS() external view returns(uint256);

    // Calculate value of LOOKS for a user given a number of shares owned
    function calculateSharesValueInLOOKS(address user) external view returns(uint256);
}
