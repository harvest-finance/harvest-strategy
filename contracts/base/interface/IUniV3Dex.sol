pragma solidity 0.5.16;

interface IUniV3Dex {
    function setFee(address token0, address token1, uint24 fee) external;
}