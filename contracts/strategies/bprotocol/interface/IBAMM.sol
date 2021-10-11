// SPDX-License-Identifier: MIT
pragma solidity 0.5.16;

/*
 * B.Protocol B.AMM V2
 */
interface IBAMM {
    function deposit(uint lusdAmount) external;

    function withdraw(uint numShares) external;

    function getCompoundedLUSDDeposit(address _depositor) external view returns (uint);
}