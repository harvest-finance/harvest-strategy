pragma solidity 0.5.16;

interface IBorrowerOperations {
    function openTrove(
        uint256 _maxFee,
        uint256 _LUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external payable;
}
