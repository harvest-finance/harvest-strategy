pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./ApeStakeStrategy.sol";

contract ApeStakeStrategyMainnet is ApeStakeStrategy {

    constructor() public {}

    function initializeStrategy(
        address _storage,
        address _vault
    ) public initializer {
        address rewardPool = address(0x5954aB967Bc958940b7EB73ee84797Dc8a2AFbb9);
        
        ApeStakeStrategy.initializeBaseStrategy(
            _storage,
            _vault,
            rewardPool
        );
    }
}
