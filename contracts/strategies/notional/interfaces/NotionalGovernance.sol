// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./Types.sol";

interface NotionalGovernance {
    event ListCurrency(uint16 newCurrencyId);
    event UpdateETHRate(uint16 currencyId);
    event UpdateAssetRate(uint16 currencyId);
    event UpdateCashGroup(uint16 currencyId);
    event DeployNToken(uint16 currencyId, address nTokenAddress);
    event UpdateDepositParameters(uint16 currencyId);
    event UpdateInitializationParameters(uint16 currencyId);
    event UpdateIncentiveEmissionRate(
        uint16 currencyId,
        uint32 newEmissionRate
    );
    event UpdateTokenCollateralParameters(uint16 currencyId);
    event UpdateGlobalTransferOperator(address operator, bool approved);
    event UpdateAuthorizedCallbackContract(address operator, bool approved);
    event UpdateMaxCollateralBalance(
        uint16 currencyId,
        uint72 maxCollateralBalance
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event PauseRouterAndGuardianUpdated(
        address indexed pauseRouter,
        address indexed pauseGuardian
    );
    event UpdateSecondaryIncentiveRewarder(
        uint16 indexed currencyId,
        address rewarder
    );
    event UpdateLendingPool(address pool);

    function transferOwnership(address newOwner, bool direct) external;

    function claimOwnership() external;

    function setPauseRouterAndGuardian(
        address pauseRouter_,
        address pauseGuardian_
    ) external;

    function listCurrency(
        Types.TokenStorage calldata assetToken,
        Types.TokenStorage calldata underlyingToken,
        address rateOracle,
        bool mustInvert,
        uint8 buffer,
        uint8 haircut,
        uint8 liquidationDiscount
    ) external returns (uint16 currencyId);

    function updateMaxCollateralBalance(
        uint16 currencyId,
        uint72 maxCollateralBalanceInternalPrecision
    ) external;

    function enableCashGroup(
        uint16 currencyId,
        address assetRateOracle,
        Types.CashGroupSettings calldata cashGroup,
        string calldata underlyingName,
        string calldata underlyingSymbol
    ) external;

    function updateDepositParameters(
        uint16 currencyId,
        uint32[] calldata depositShares,
        uint32[] calldata leverageThresholds
    ) external;

    function updateInitializationParameters(
        uint16 currencyId,
        uint32[] calldata annualizedAnchorRates,
        uint32[] calldata proportions
    ) external;

    function updateIncentiveEmissionRate(
        uint16 currencyId,
        uint32 newEmissionRate
    ) external;

    function updateTokenCollateralParameters(
        uint16 currencyId,
        uint8 residualPurchaseIncentive10BPS,
        uint8 pvHaircutPercentage,
        uint8 residualPurchaseTimeBufferHours,
        uint8 cashWithholdingBuffer10BPS,
        uint8 liquidationHaircutPercentage
    ) external;

    function updateCashGroup(
        uint16 currencyId,
        Types.CashGroupSettings calldata cashGroup
    ) external;

    function updateAssetRate(uint16 currencyId, address rateOracle) external;

    function updateETHRate(
        uint16 currencyId,
        address rateOracle,
        bool mustInvert,
        uint8 buffer,
        uint8 haircut,
        uint8 liquidationDiscount
    ) external;

    function updateGlobalTransferOperator(address operator, bool approved)
        external;

    function updateAuthorizedCallbackContract(address operator, bool approved)
        external;

    function setLendingPool(address pool) external;

    function setSecondaryIncentiveRewarder(uint16 currencyId, address rewarder)
        external;
}
