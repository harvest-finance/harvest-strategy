// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.5.16;

interface NotionalTreasury {
    /// @notice Emitted when reserve balance is updated
    event ReserveBalanceUpdated(uint16 indexed currencyId, int256 newBalance);
    /// @notice Emitted when reserve balance is harvested
    event ExcessReserveBalanceHarvested(
        uint16 indexed currencyId,
        int256 harvestAmount
    );
    /// @dev Emitted when treasury manager is updated
    event TreasuryManagerChanged(
        address indexed previousManager,
        address indexed newManager
    );
    /// @dev Emitted when reserve buffer value is updated
    event ReserveBufferUpdated(uint16 currencyId, uint256 bufferAmount);

    function claimCOMPAndTransfer(address[] calldata ctokens)
        external
        returns (uint256);

    function transferReserveToTreasury(uint16[] calldata currencies)
        external
        returns (uint256[] memory);

    function setTreasuryManager(address manager) external;

    function setReserveBuffer(uint16 currencyId, uint256 amount) external;

    function setReserveCashBalance(uint16 currencyId, int256 reserveBalance)
        external;
}
