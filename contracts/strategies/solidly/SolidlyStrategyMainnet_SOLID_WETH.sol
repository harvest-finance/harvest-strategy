// SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./SolidlyStrategy.sol";

contract SolidlyStrategyMainnet_SOLID_WETH is SolidlyStrategy {

    constructor() public {}

    function initializeStrategy(
        address _storage,
        address _vault
    ) public initializer {
        address underlying = address(0x642431623AE5d73C19fC931aAeA0d4677303880c);
        address gauge = address(0x84674cFFB6146D19b986fC88EC70a441b570A45B);
        address solid = address(0x777172D858dC1599914a1C4c6c9fC48c99a60990);
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        SolidlyStrategy.initializeBaseStrategy(
            _storage,
            underlying,
            _vault,
            gauge,
            weth
        );

        rewardTokens.push(solid);
    }
}