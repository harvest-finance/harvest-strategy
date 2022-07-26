pragma solidity ^0.5.16;


interface IStargateRouter {

    function addLiquidity(uint256 _poolId, uint256 _amount, address _to) external;
}