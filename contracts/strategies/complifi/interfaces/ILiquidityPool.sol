pragma solidity 0.5.16;

interface ILiquidityPool {

    function repricingBlock() external view returns(uint);

    function baseFee() external view returns(uint);
    function feeAmp() external view returns(uint);
    function maxFee() external view returns(uint);

    function pMin() external view returns(uint);
    function qMin() external view returns(uint);
    function exposureLimit() external view returns(uint);
    function volatility() external view returns(uint);

    function derivativeVault() external view returns(address);
    function dynamicFee() external view returns(address);
    function repricer() external view returns(address);

    function isFinalized()
    external view
    returns (bool);

    function getNumTokens()
    external view
    returns (uint);

    function getTokens()
    external view
    returns (address[] memory tokens);

    function getLeverage(address token)
    external view
    returns (uint);

    function getBalance(address token)
    external view
    returns (uint);

    function getController()
    external view
    returns (address);

    function setController(address manager)
    external;


    function joinPool(uint poolAmountOut, uint[2] calldata maxAmountsIn)
    external;

    function exitPool(uint poolAmountIn, uint[2] calldata minAmountsOut)
    external;

    function swapExactAmountIn(
        address tokenIn,
        uint tokenAmountIn,
        address tokenOut,
        uint minAmountOut
    )
    external
    returns (uint tokenAmountOut, uint spotPriceAfter);
}
