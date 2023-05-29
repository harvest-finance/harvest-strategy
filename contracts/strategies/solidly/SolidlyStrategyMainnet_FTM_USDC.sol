// SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./SolidlyStrategy.sol";

contract SolidlyStrategyMainnet_FTM_USDC is SolidlyStrategy {

    constructor() public {}

    function initializeStrategy(
        address _storage,
        address _vault
    ) public initializer {
        address underlying = address(0x3f18C8C09ca97B7E8C14C09BfFd02E89753Cf602);
        address gauge = address(0x09a44A8360049D039265EF31ecdeBf00D4c42C7A);
        address solid = address(0x777172D858dC1599914a1C4c6c9fC48c99a60990);
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        address ftm = address(0x4E15361FD6b4BB609Fa63C81A2be19d873717870);
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
        storedLiquidationDexes[weth][ftm] = [uniV3Dex];
        storedLiquidationPaths[weth][ftm] = [weth, ftm];
    }
}