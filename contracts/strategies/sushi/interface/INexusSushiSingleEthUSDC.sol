// SPDX-License-Identifier: MIT
// solhint-disable

pragma solidity ^0.5.0;

contract INexusSushiSingleEthUSDC {
    function compoundProfits()
        external
        payable
        returns (
            uint256 usd,
            uint256 eth,
            uint256 liquidity
        );

    function claimRewards() external;
}
