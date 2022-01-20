pragma solidity 0.5.16;

/**
 * Contract used to simulate rewards distrubation at LOOKS smart contracts in our tests
 */
interface IOperatorControllerForRewards {
    // only executable by owner
    function releaseTokensAndUpdateRewards() external;
}