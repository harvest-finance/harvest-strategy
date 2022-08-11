pragma solidity ^0.5.16;


interface IStargateToken {

    function poolId() external view returns (uint256);

    function token() external view returns (address);
}