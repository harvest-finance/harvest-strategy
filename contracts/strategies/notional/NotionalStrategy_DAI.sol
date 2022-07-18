pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./NotionalStrategy.sol";

contract NotionalStrategyMainnet_DAI is NotionalStrategy {
    constructor() public {}

    function initializeStrategy(address _storage, address _vault)
        public
        initializer
    {
        address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address proxy = address(0x1344A36A1B56144C3Bc62E7757377D288fDE0369);

        bytes32 uniV3Dex = 0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f;

        NotionalStrategy.initializeBaseStrategy(
            _storage,
            address(0x6EbcE2453398af200c688C7c4eBD479171231818), // nDai
            _vault,
            proxy, // notional proxy
            2 // currencyId
        );

        storedLiquidationPaths[weth][dai] = [weth, dai];
        storedLiquidationDexes[weth][dai] = [uniV3Dex];
    }
}
