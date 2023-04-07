// SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./SolidlyStrategy.sol";

contract SolidlyStrategyMainnet_LQTY_WETH is SolidlyStrategy {

    constructor() public {}

    function initializeStrategy(
        address _storage,
        address _vault
    ) public initializer {
        address underlying = address(0x1eA327e557d948cCC4AfaFBDDC2Ae00A89448Dc3);
        address gauge = address(0x024AA76179de60bc64bF2FdC6a4Ccce8AA7e7501);
        address solid = address(0x777172D858dC1599914a1C4c6c9fC48c99a60990);
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address lqty = address(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D);
        bytes32 uniV3Dex = 0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f;

        SolidlyStrategy.initializeBaseStrategy(
            _storage,
            underlying,
            _vault,
            gauge,
            weth
        );

        rewardTokens.push(solid);
        storedLiquidationDexes[weth][lqty] = [uniV3Dex];
        storedLiquidationPaths[weth][lqty] = [weth, lqty];
    }
}