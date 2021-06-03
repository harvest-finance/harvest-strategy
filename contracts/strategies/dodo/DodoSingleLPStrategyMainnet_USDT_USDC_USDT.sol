pragma solidity 0.5.16;

import "../../base/dodo-base/DodoV1SingleLPStrategy.sol";

contract DodoV1SingleLPStrategyMainnet_USDT_USDC_USDT is
    DodoV1SingleLPStrategy
{
    // Just a differentiator for the bytecode
    address public dodo_usdt_usdc_usdt;

    constructor() public {}

    function initializeStrategy(address _storage, address _vault)
        public
        initializer
    {
        // USDT LP token for DODO V1 USDT/USDC pair
        address underlying =
            address(0x50b11247bF14eE5116C855CDe9963fa376FceC86);

        DodoV1SingleLPStrategy.initializeBaseStrategy(
            _storage,
            underlying,
            _vault,
            address(0xaeD7384F03844Af886b830862FF0a7AFce0a632C), // DODO Mine
            address(0xC9f93163c99695c6526b799EbcA2207Fdf7D61aD), // DODO V1 USDT/USDC pair
            true // Is base token in the pair
        );

        // The reward token is USDT, so no need to setup any Uniswap routes for buyback
        // uniswapRoutes[usdt] = [...];
    }
}
