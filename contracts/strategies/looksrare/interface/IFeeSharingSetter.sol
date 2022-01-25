pragma solidity 0.5.16;

/**
 * Contract used to simulate rewards distrubation at LOOKS smart contracts in our tests
 */
interface IFeeSharingSetter {
    // only executable by operator role
    function updateRewards() external;

    function rewardDurationInBlocks() external view returns(uint256);

    function lastRewardDistributionBlock() external view returns(uint256);
}