pragma solidity 0.5.16;

interface IUSDCVault {
    /// @notice vault initialization time
    function initializationTime() external view returns(uint256);
    /// @notice start of live period
    function liveTime() external view returns(uint256);
    /// @notice end of live period
    function settleTime() external view returns(uint256);

    /// @notice underlying value at the start of live period
    function underlyingStarts(uint index) external view returns(int256);
    /// @notice underlying value at the end of live period
    function underlyingEnds(uint index) external view returns(int256);

    /// @notice primary token conversion rate multiplied by 10 ^ 12
    function primaryConversion() external view returns(uint256);
    /// @notice complement token conversion rate multiplied by 10 ^ 12
    function complementConversion() external view returns(uint256);

    // @notice derivative specification address
    function derivativeSpecification() external view returns(address);
    // @notice collateral token address
    function collateralToken() external view returns(address);
    // @notice oracle address
    function oracles(uint index) external view returns(address);
    function oracleIterators(uint index) external view returns(address);

    // @notice primary token address
    function primaryToken() external view returns(address);
    // @notice complement token address
    function complementToken() external view returns(address);

    function mint(uint256 _collateralAmount) external;

    function mintTo(address _recipient, uint256 _collateralAmount) external;

    function refund(uint256 _tokenAmount) external;

    function refundTo(address _recipient, uint256 _tokenAmount) external;

    function redeem(
        uint256 _primaryTokenAmount,
        uint256 _complementTokenAmount,
        uint256[] calldata _underlyingEndRoundHints
    ) external;

    function redeemTo(
        address _recipient,
        uint256 _primaryTokenAmount,
        uint256 _complementTokenAmount,
        uint256[] calldata _underlyingEndRoundHints
    ) external;
}
