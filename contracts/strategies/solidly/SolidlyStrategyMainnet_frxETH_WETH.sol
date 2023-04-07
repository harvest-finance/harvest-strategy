// SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./SolidlyStrategy.sol";

contract SolidlyStrategyMainnet_frxETH_WETH is SolidlyStrategy {

    constructor() public {}

    function initializeStrategy(
        address _storage,
        address _vault
    ) public initializer {
        address underlying = address(0x4E30fc7ccD2dF3ddCA39a69d2085334Ee63b9c96);
        address gauge = address(0x36f10d9A68fb22b666554D818BBaEF428ce55241);
        address solid = address(0x777172D858dC1599914a1C4c6c9fC48c99a60990);
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address frxEth = address(0x5E8422345238F34275888049021821E8E08CAa1f);
        bytes32 uniV3Dex = 0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f;

        SolidlyStrategy.initializeBaseStrategy(
            _storage,
            underlying,
            _vault,
            gauge,
            weth
        );

        rewardTokens.push(solid);
        storedLiquidationDexes[weth][frxEth] = [uniV3Dex];
        storedLiquidationPaths[weth][frxEth] = [weth, frxEth];
    }
}