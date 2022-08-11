pragma solidity ^0.5.16;

import "./StargateStrategy.sol";


contract UsdtStargateStrategyMainnet is StargateStrategy {

    constructor() public {}

    function initializeStrategy(
        address _storage,
        address _vault
    ) public initializer {
        StargateStrategy.initializeStargateStrategy(
            _storage,
            address(0x38EA452219524Bb87e18dE1C24D3bB59510BD783), // USDT Pool
            _vault,
            address(0xB0D502E938ed5f4df2E681fE6E419ff29631d62b), // LP Staking Pool
            address(0xdAC17F958D2ee523a2206206994597C13D831ec7), // USDT
            address(0x8731d54E9D02c286767d56ac03e8037C07e01e98), // Stargate router
            2,
            1
        );
    }
}