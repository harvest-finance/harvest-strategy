// SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;

interface ISolidlyPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function stable() external view returns (bool);
}