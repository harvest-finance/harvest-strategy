pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./NotionalStrategy.sol";

contract NotionalStrategyMainnet_WBTC is NotionalStrategy {
    constructor() public {}

    function initializeStrategy(address _storage, address _vault)
        public
        initializer
    {
        address wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address proxy = address(0x1344A36A1B56144C3Bc62E7757377D288fDE0369);

        bytes32 uniV3Dex = 0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f;

        NotionalStrategy.initializeBaseStrategy(
            _storage,
            address(0x0Ace2DC3995aCD739aE5e0599E71A5524b93b886), // nWBTC
            _vault,
            proxy, // notional proxy
            4 // currencyId
        );

        storedLiquidationPaths[weth][wbtc] = [weth, wbtc];
        storedLiquidationDexes[weth][wbtc] = [uniV3Dex];
    }
}
