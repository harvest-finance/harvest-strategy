// SPDX-License-Identifier: MIT
// solhint-disable

pragma solidity ^0.5.0;

interface INexusLPSushi {
    function owner() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external;

    function pricePerFullShare() external view returns (uint256);

    function availableSpaceToDepositETH() external view returns (uint256 amountETH);

    function depositCapital(uint256 amount) external;

    function addLiquidityETH(address beneficiary, uint256 deadline) external;

    function removeLiquidityETH(
        address payable beneficiary,
        uint256 shares,
        uint256 deadline
    ) external returns (uint256 exitETH);

    function removeAllLiquidityETH(address payable beneficiary, uint256 deadline) external returns (uint256 exitETH);

    function setGovernance(address _governance) external;

    function claimRewards() external;

    function compoundProfits(uint256 amountETH, uint256 capitalProviderRewardPercentmil)
        external
        returns (
            uint256 pairedUSDC,
            uint256 pairedETH,
            uint256 liquidity
        );
}
