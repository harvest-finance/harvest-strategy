// SPDX-License-Identifier: MIT
pragma solidity 0.5.16;

/*
 * B.Protocol B.AMM V2
 */
interface IBAMM {
    function SP() external view returns (address);

    function deposit(uint lusdAmount) external;

    function withdraw(uint numShares) external;

    function balanceOf(address owner) external view returns (uint balance);

    function totalSupply() external view returns (uint);
    
    function fetchPrice() external view returns(uint);
}