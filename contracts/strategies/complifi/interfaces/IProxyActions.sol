pragma solidity 0.5.16;

interface IProxyActions {
    function mintAndJoinPool(address _pool, uint256 _collateralAmount, address, uint256, address, uint256, uint256) external;
    function extractChange(address _pool) external;
    function redeem(address _vault, uint256 _primaryTokenAmount, uint256 _complementTokenAmount, uint256[] calldata) external;
    function removeLiquidityOnLiveOrMintingState(address _pool, uint256 _poolAmountIn, address, uint256, uint256, uint256[2] calldata) external;
    function removeLiquidityOnSettledState(address _pool, uint256 _poolAmountIn, uint256, uint256[2] calldata, uint256[] calldata) external;
}
