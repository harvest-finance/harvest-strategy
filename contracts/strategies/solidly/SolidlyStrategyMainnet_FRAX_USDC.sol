// SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./SolidlyStrategy.sol";

contract SolidlyStrategyMainnet_FRAX_USDC is SolidlyStrategy {

    constructor() public {}

    function initializeStrategy(
        address _storage,
        address _vault
    ) public initializer {
        address underlying = address(0x7d8311F7E0C1D19C1096E43E8B6C17b67Fb6AA2e);
        address gauge = address(0x810E190Be9592615D75c514C0f9D8c9b79eB8056);
        address solid = address(0x777172D858dC1599914a1C4c6c9fC48c99a60990);
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        address frax = address(0x853d955aCEf822Db058eb8505911ED77F175b99e);
        bytes32 uniV3Dex = 0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f;

        SolidlyStrategy.initializeBaseStrategy(
            _storage,
            underlying,
            _vault,
            gauge,
            weth
        );

        rewardTokens.push(solid);
        storedLiquidationDexes[weth][usdc] = [uniV3Dex];
        storedLiquidationPaths[weth][usdc] = [weth, usdc];
        storedLiquidationDexes[weth][frax] = [uniV3Dex];
        storedLiquidationPaths[weth][frax] = [weth, frax];
    }
}