pragma solidity 0.5.16;

interface IBalancerDex {
    function changeVault (address newVault) external;
    function changePoolId (address token0, address token1, bytes32 poolId) external;
}