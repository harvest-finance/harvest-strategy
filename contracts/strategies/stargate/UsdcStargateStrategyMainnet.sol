pragma solidity ^0.5.16;

import "./StargateStrategy.sol";


contract UsdcStargateStrategyMainnet is StargateStrategy {

    constructor() public {}

    function initializeStrategy(
        address _storage,
        address _vault
    ) public initializer {
        StargateStrategy.initializeStargateStrategy(
            _storage,
            address(0xdf0770dF86a8034b3EFEf0A1Bb3c889B8332FF56), // USDC Pool
            _vault,
            address(0xB0D502E938ed5f4df2E681fE6E419ff29631d62b), // LP Staking Pool
            address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48), // USDC
            address(0x8731d54E9D02c286767d56ac03e8037C07e01e98), // Stargate router
            1,
            0
        );
    }
}