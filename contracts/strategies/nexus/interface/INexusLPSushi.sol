// SPDX-License-Identifier: MIT
// solhint-disable

pragma solidity ^0.5.0;

interface INexusLPSushi {
    function claimRewards() external;

    function compoundProfits(uint256 amountETH)
        external
        returns (
            uint256 addedUSDC,
            uint256 addedETH,
            uint256 liquidity
        );
}
