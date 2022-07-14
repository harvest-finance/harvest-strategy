pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./NotionalStrategy.sol";

contract NotionalStrategyMainnet_USDC is NotionalStrategy {
    constructor() public {}

    function initializeStrategy(address _storage, address _vault)
        public
        initializer
    {
        address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address proxy = address(0x1344A36A1B56144C3Bc62E7757377D288fDE0369);

        bytes32 uniV3Dex = 0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f;

        NotionalStrategy.initializeBaseStrategy(
            _storage,
            address(0x18b0Fc5A233acF1586Da7C199Ca9E3f486305A29), // nUSDC
            _vault,
            proxy, // notional proxy
            3 // currencyId
        );

        storedLiquidationPaths[weth][usdc] = [weth, usdc];
        storedLiquidationDexes[weth][usdc] = [uniV3Dex];
    }
}
