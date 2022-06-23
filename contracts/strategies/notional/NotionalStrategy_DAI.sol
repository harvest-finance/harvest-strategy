pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./NotionalStrategy.sol";

contract NotionalStrategy_DAI is NotionalStrategy {
    constructor() public {}

    function initializeStrategy(address _storage, address _vault)
        public
        initializer
    {
        address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address proxy = address(0x1344A36A1B56144C3Bc62E7757377D288fDE0369);

        bytes32 uniDex = 0xde2d1a51640f78257713031680d1f306297d957426e912ab21317b9cc9495a41;

        NotionalStrategy.initializeBaseStrategy(
            _storage,
            address(0x6EbcE2453398af200c688C7c4eBD479171231818), // nDai
            _vault,
            proxy, // notional proxy
            address(0xBA12222222228d8Ba445958a75a0704d566BF2C8), //balancer vault
            0x5122e01d819e58bb2e22528c0d68d310f0aa6fd7000200000000000000000163, // note2wethpid
            2 // currencyId
        );

        storedLiquidationPaths[weth][dai] = [weth, dai];
        storedLiquidationDexes[weth][dai] = [uniDex];
    }
}
