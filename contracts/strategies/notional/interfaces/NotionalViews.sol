// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./Types.sol";

interface NotionalViews {
    function getMaxCurrencyId() external view returns (uint16);

    function getCurrencyId(address tokenAddress)
        external
        view
        returns (uint16 currencyId);

    function getCurrency(uint16 currencyId)
        external
        view
        returns (
            Types.Token memory assetToken,
            Types.Token memory underlyingToken
        );

    function getRateStorage(uint16 currencyId)
        external
        view
        returns (
            Types.ETHRateStorage memory ethRate,
            Types.AssetRateStorage memory assetRate
        );

    function getCurrencyAndRates(uint16 currencyId)
        external
        view
        returns (
            Types.Token memory assetToken,
            Types.Token memory underlyingToken,
            Types.ETHRate memory ethRate,
            Types.AssetRateParameters memory assetRate
        );

    function getCashGroup(uint16 currencyId)
        external
        view
        returns (Types.CashGroupSettings memory);

    function getCashGroupAndAssetRate(uint16 currencyId)
        external
        view
        returns (
            Types.CashGroupSettings memory cashGroup,
            Types.AssetRateParameters memory assetRate
        );

    function getInitializationParameters(uint16 currencyId)
        external
        view
        returns (
            int256[] memory annualizedAnchorRates,
            int256[] memory proportions
        );

    function getDepositParameters(uint16 currencyId)
        external
        view
        returns (
            int256[] memory depositShares,
            int256[] memory leverageThresholds
        );

    function nTokenAddress(uint16 currencyId) external view returns (address);

    function getNoteToken() external view returns (address);

    function getOwnershipStatus()
        external
        view
        returns (address owner, address pendingOwner);

    function getGlobalTransferOperatorStatus(address operator)
        external
        view
        returns (bool isAuthorized);

    function getAuthorizedCallbackContractStatus(address callback)
        external
        view
        returns (bool isAuthorized);

    function getSecondaryIncentiveRewarder(uint16 currencyId)
        external
        view
        returns (address incentiveRewarder);

    function getSettlementRate(uint16 currencyId, uint40 maturity)
        external
        view
        returns (Types.AssetRateParameters memory);

    function getMarket(
        uint16 currencyId,
        uint256 maturity,
        uint256 settlementDate
    ) external view returns (Types.MarketParameters memory);

    function getActiveMarkets(uint16 currencyId)
        external
        view
        returns (Types.MarketParameters[] memory);

    function getActiveMarketsAtBlockTime(uint16 currencyId, uint32 blockTime)
        external
        view
        returns (Types.MarketParameters[] memory);

    function getReserveBalance(uint16 currencyId)
        external
        view
        returns (int256 reserveBalance);

    function getNTokenPortfolio(address tokenAddress)
        external
        view
        returns (
            Types.PortfolioAsset[] memory liquidityTokens,
            Types.PortfolioAsset[] memory netfCashAssets
        );

    function getNTokenAccount(address tokenAddress)
        external
        view
        returns (
            uint16 currencyId,
            uint256 totalSupply,
            uint256 incentiveAnnualEmissionRate,
            uint256 lastInitializedTime,
            bytes5 nTokenParameters,
            int256 cashBalance,
            uint256 accumulatedNOTEPerNToken,
            uint256 lastAccumulatedTime
        );

    function getAccount(address account)
        external
        view
        returns (
            Types.AccountContext memory accountContext,
            Types.AccountBalance[] memory accountBalances,
            Types.PortfolioAsset[] memory portfolio
        );

    function getAccountContext(address account)
        external
        view
        returns (Types.AccountContext memory);

    function getAccountBalance(uint16 currencyId, address account)
        external
        view
        returns (
            int256 cashBalance,
            int256 nTokenBalance,
            uint256 lastClaimTime
        );

    function getAccountPortfolio(address account)
        external
        view
        returns (Types.PortfolioAsset[] memory);

    function getfCashNotional(
        address account,
        uint16 currencyId,
        uint256 maturity
    ) external view returns (int256);

    function getAssetsBitmap(address account, uint16 currencyId)
        external
        view
        returns (bytes32);

    function getFreeCollateral(address account)
        external
        view
        returns (int256, int256[] memory);

    function getTreasuryManager() external view returns (address);

    function getReserveBuffer(uint16 currencyId)
        external
        view
        returns (uint256);

    function getLendingPool() external view returns (address);
}
