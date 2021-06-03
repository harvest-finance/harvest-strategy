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
        // USDT LP token
        address underlying =
            address(0x50b11247bF14eE5116C855CDe9963fa376FceC86);

        address dodo = address(0x43Dfc4159D86F3A37A5A4B3D4580b888ad7d4DDd);
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address usdt = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);

        DodoV1SingleLPStrategy.initializeStrategy(
            _storage,
            underlying,
            _vault,
            address(0xaeD7384F03844Af886b830862FF0a7AFce0a632C), // DODO Mine
            dodo,
            address(0xC9f93163c99695c6526b799EbcA2207Fdf7D61aD), // DODO V1 USDT/USDC pair
            true // Is base token in the pair
        );

        // Liquidate DODO rewards to USDT
        uniswapRoutes[usdt] = [dodo, weth, usdt];
    }
}
