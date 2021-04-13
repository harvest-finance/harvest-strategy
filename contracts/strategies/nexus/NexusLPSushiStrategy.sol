// SPDX-License-Identifier: MIT

pragma solidity ^0.5.16;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interface/INexusLPSushi.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/upgradability/BaseUpgradeableStrategy.sol";
import "../../base/interface/uniswap/IUniswapV2Router02.sol";

/**
 * Strategy implementing NexusLPSushi auto compounding with reward distribuion
 * Deposit your ETH to make more ETH
 * NexusLP tokens are kept here and not sent to the underlying pool
 * // TODO talkol do your magic
 */
contract NexusLPSushiStrategy is IStrategy, BaseUpgradeableStrategy {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant ROUTER = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F); // Sushiswap Router2
    address public constant REWARD = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2); // Sushi
    address public constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    uint256 public constant CAPITAL_PROVIDER_REWARD_PERCENTMIL = 20_000; // 20% of rewards to USDC provider

    function initializeStrategy(
        address _storage,
        address _underlying,
        address _vault
    ) public initializer {
        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _underlying,
            REWARD,
            300, // profit sharing numerator
            1000, // profit sharing denominator
            true, // sell
            1e18, // sell floor
            12 hours // implementation change delay
        );
    }

    function depositArbCheck() external view returns (bool) {
        return true;
    }

    function unsalvagableTokens(address token) public view returns (bool) {
        return (token == rewardToken() || token == underlying());
    }

    /*
     * Returns NexusLP token balance of this
     */
    function investedUnderlyingBalance() external view returns (uint256) {
        return IERC20(underlying()).balanceOf(address(this));
    }

    /**
     * As we keep all NexusLP tokens here, we just send them back to the vault
     */
    function withdrawAllToVault() external restricted {
        uint256 balance = IERC20(underlying()).balanceOf(address(this));
        if (balance > 0) {
            IERC20(underlying()).safeTransfer(vault(), balance);
        }
    }

    /*
     * As we keep all NexusLP tokens here, we just send them back to the vault
     */
    function withdrawToVault(uint256 amount) external restricted {
        IERC20(underlying()).safeTransfer(vault(), amount);
    }

    /*
     *   Governance or Controller can claim coins that are somehow transferred into the contract
     *   Note that they cannot come in take away coins that are used and defined in the strategy itself
     */
    function salvage(
        address recipient,
        address token,
        uint256 amount
    ) external onlyControllerOrGovernance {
        // To make sure that governance cannot come in and take away the coins
        require(!unsalvagableTokens(token), "token is not salvagable");
        IERC20(token).safeTransfer(recipient, amount);
    }

    /*
     *   Get the reward, sell it in exchange for underlying, invest what you got.
     *   It's not much, but it's honest work.
     */
    function doHardWork() external onlyNotPausedInvesting restricted {
        INexusLPSushi(underlying()).claimRewards();

        _liquidateReward();

        uint256 entireBalance = IERC20(WETH).balanceOf(address(this));
        if (entireBalance > 0) {
            IERC20(WETH).safeApprove(underlying(), 0);
            IERC20(WETH).safeApprove(underlying(), entireBalance);
            INexusLPSushi(underlying()).compoundProfits(entireBalance, CAPITAL_PROVIDER_REWARD_PERCENTMIL);
        }
    }

    /*
     *   In case there are some issues discovered about the pool or underlying asset
     *   Governance can exit the pool properly
     *   The function is only used for emergency to exit the pool
     */
    function emergencyExit() public onlyGovernance {
        _setPausedInvesting(true);
    }

    /*
     *   Resumes the ability to invest into the underlying reward pools
     */
    function continueInvesting() public onlyGovernance {
        _setPausedInvesting(false);
    }

    // We assume that all the tradings can be done on Sushiswap
    function _liquidateReward() internal {
        uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
        if (!sell() || rewardBalance < sellFloor()) {
            // Profits can be disabled for possible simplified and rapid exit
            emit ProfitsNotCollected(sell(), rewardBalance < sellFloor());
            return;
        }

        notifyProfitInRewardToken(rewardBalance); // handles all fees

        uint256 remainingRewardBalance = IERC20(rewardToken()).balanceOf(address(this));

        if (remainingRewardBalance > 0) {
            IERC20(rewardToken()).safeApprove(ROUTER, 0);
            IERC20(rewardToken()).safeApprove(ROUTER, remainingRewardBalance);

            uint256 amountOutMin = 1; // we can accept 1 as minimum because this is called only by a trusted role
            address[] memory path = new address[](2);
            path[0] = REWARD;
            path[1] = WETH;
            IUniswapV2Router02(ROUTER).swapExactTokensForTokens(remainingRewardBalance, amountOutMin, path, address(this), block.timestamp);
        }
    }
}
