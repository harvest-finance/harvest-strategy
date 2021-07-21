pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../../base/upgradability/BaseUpgradeableStrategyUL.sol";

import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "../../base/interface/weth/Weth9.sol";
import "./interface/ICurveMetapool.sol";
import "./interface/ILQTYStaking.sol";
import "./interface/ISwapRouter.sol";

contract LQTYStakingStrategy is IStrategy, BaseUpgradeableStrategyUL {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address private lusd;
    address private lqty;
    address private usdc;
    address private weth;
    address private lqtyStaking;
    address private lusd3CrvPair;

    // ---------------- Constructor ----------------

    constructor() public BaseUpgradeableStrategyUL() {}

    // ---------------- Initializer ----------------

    function initializeBaseStrategy(
        address _storage,
        address _vault,
        address _lusd,
        address _lqty,
        address _usdc,
        address _weth,
        address _lqtyStaking,
        address _lusd3CrvPair
    ) public initializer {
        BaseUpgradeableStrategyUL.initialize(
            _storage,
            _lqty,
            _vault,
            _lqtyStaking,
            // Rewards are actually given in LUSD and ETH. However, for
            // improved liquidity usage simplification, we liquidate the
            // rewards to WETH and use that as the reward token
            _weth,
            300, // Profit sharing numerator
            1000, // Profit sharing denominator
            true, // Sell
            1e6, // Sell floor
            12 hours, // Implementation change delay
            address(0x7882172921E99d590E097cD600554339fBDBc480) // UL Registry
        );

        lusd = _lusd;
        lqty = _lqty;
        usdc = _usdc;
        weth = _weth;
        lqtyStaking = _lqtyStaking;
        lusd3CrvPair = _lusd3CrvPair;
    }

    // ---------------- Payable fallback -----------------

    function() external payable {
        // Needed for ETH rewards
    }

    // ---------------- IStrategy methods ----------------

    function unsalvagableTokens(address token) public view returns (bool) {
        return (token == lqty);
    }

    /**
     * @dev Withdraws everything back to the vault.
     */
    function withdrawAllToVault() public restricted {
        if (address(rewardPool()) != address(0)) {
            exitRewardPool();
        }
        _liquidateReward();
        IERC20(underlying()).safeTransfer(
            vault(),
            IERC20(underlying()).balanceOf(address(this))
        );
    }

    function withdrawToVault(uint256 amount) public restricted {
        // Typically there wouldn't be any coins here - however, this would
        // still be possible because of an emergency exit
        uint256 currentBalance = IERC20(underlying()).balanceOf(address(this));

        if (amount > currentBalance) {
            // While we have the check above, we're still using SafeMath, just
            // for peace of mind (in case something gets changed in between)
            uint256 needToWithdraw = amount.sub(currentBalance);
            uint256 toWithdraw = Math.min(rewardPoolBalance(), needToWithdraw);
            ILQTYStaking(rewardPool()).unstake(toWithdraw);
        }

        IERC20(underlying()).safeTransfer(vault(), amount);
    }

    /**
     * @dev Note that we currently don't have a mechanism here to include
     *      the accrued rewards.
     */
    function investedUnderlyingBalance() external view returns (uint256) {
        if (address(rewardPool()) == address(0)) {
            return IERC20(underlying()).balanceOf(address(this));
        }
        // Add the amount locked in the reward pool and the amount that resides in this contract
        // (both are in the units of "underlying")
        // The second part is needed because of the emergency exit mechanism, which would break
        // the assumption that all funds are inside the reward pool
        return
            rewardPoolBalance().add(
                IERC20(underlying()).balanceOf(address(this))
            );
    }

    /**
     * @dev Governance or controller can claim coins that are somehow transferred
     *      into the contract (eg. by mistake). Note that the underlying LP token
     *      is not salvagable.
     */
    function salvage(
        address recipient,
        address token,
        uint256 amount
    ) external onlyControllerOrGovernance {
        // Make sure governance or controller cannot come in and take away the invested tokens
        require(
            !unsalvagableTokens(token),
            "Token is defined as non-salvagable"
        );
        IERC20(token).safeTransfer(recipient, amount);
    }

    function depositArbCheck() public view returns (bool) {
        return true;
    }

    function doHardWork() external onlyNotPausedInvesting restricted {
        claimRewards();
        _liquidateReward();
        investAllUnderlying();
    }

    // ---------------- Governance-only methods ----------------

    /**
     * @dev In case there are issues with the pool or underlying asset,
     *      governance can still trigger an emergency exit, in order to
     *      pause investing in the pool.
     */
    function emergencyExit() public onlyGovernance {
        _setPausedInvesting(true);
        exitRewardPool();
    }

    /**
     * @dev Resumes the ability to invest into the underlying rewards pool.
     */
    function continueInvesting() public onlyGovernance {
        _setPausedInvesting(false);
    }

    /**
     * @dev Can completely disable liquidation of DODO rewards. This can be
     *      useful in case of emergency exits.
     */
    function setSell(bool _sell) public onlyGovernance {
        _setSell(_sell);
    }

    /**
     * @dev Set the minimum amount of DODO needed to trigger a sale (for a liquidation).
     */
    function setSellFloor(uint256 _sellFloor) public onlyGovernance {
        setSellFloor(_sellFloor);
    }

    function finalizeUpgrade() external onlyGovernance {
        _finalizeUpgrade();

        // Reset the liquidation paths - they need to be reset manually
        storedLiquidationPaths[usdc][weth] = new address[](0);
        storedLiquidationDexes[usdc][weth] = new bytes32[](0);
        storedLiquidationPaths[weth][lqty] = new address[](0);
        storedLiquidationDexes[weth][lqty] = new bytes32[](0);
    }

    // ---------------- Internal methods ----------------

    function rewardPoolBalance() internal view returns (uint256 balance) {
        balance = ILQTYStaking(rewardPool()).stakes(address(this));
    }

    function claimRewards() internal {
        if (rewardPoolBalance() > 0) {
            ILQTYStaking(rewardPool()).unstake(0);
        }
    }

    function enterRewardPool() internal {
        uint256 currentBalance = IERC20(underlying()).balanceOf(address(this));
        ILQTYStaking(rewardPool()).stake(currentBalance);
    }

    function exitRewardPool() internal {
        uint256 staked = rewardPoolBalance();
        if (staked > 0) {
            ILQTYStaking(rewardPool()).unstake(staked);
        }
    }

    /**
     * @dev Stakes everything the strategy holds into the reward pool.
     */
    function investAllUnderlying() internal onlyNotPausedInvesting {
        // This check is needed for avoiding reverts in case we stake 0
        if (IERC20(underlying()).balanceOf(address(this)) > 0) {
            enterRewardPool();
        }
    }

    function _liquidateReward() internal {
        // Profits can be disabled for possible simplified and rapid exit
        if (!sell()) {
            emit ProfitsNotCollected(sell(), true);
            return;
        }

        uint256 lusdBalance = IERC20(lusd).balanceOf(address(this));
        if (lusdBalance > 0) {
            // First, liquidate the LUSD rewards to USDC on Curve
            // as that's where most of the LUSD liquidity resides
            IERC20(lusd).safeApprove(lusd3CrvPair, 0);
            IERC20(lusd).safeApprove(lusd3CrvPair, lusdBalance);
            ICurveMetapool(lusd3CrvPair).exchange_underlying(
                0,
                2,
                lusdBalance,
                1
            );

            // Then, liquidate the USDC to WETH
            uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
            if (usdcBalance > 0) {
                IERC20(usdc).safeApprove(universalLiquidator(), 0);
                IERC20(usdc).safeApprove(universalLiquidator(), usdcBalance);
                ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
                    usdcBalance,
                    1,
                    address(this),
                    storedLiquidationDexes[usdc][weth],
                    storedLiquidationPaths[usdc][weth]
                );
            }
        }

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            // Wrap the ETH rewards to WETH
            WETH9(weth).deposit.value(ethBalance)();
        }

        // At this point, both LUSD and ETH rewards were liquidated/wrapped
        // to WETH, which we now use as the reward token
        uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));

        // Profits can be disabled for possible simplified and rapid exit
        if (rewardBalance < sellFloor()) {
            emit ProfitsNotCollected(sell(), rewardBalance < sellFloor());
            return;
        }

        notifyProfitInRewardToken(rewardBalance);
        uint256 remainingRewardBalance = IERC20(rewardToken()).balanceOf(
            address(this)
        );

        if (remainingRewardBalance == 0) {
            return;
        }

        // Liquidate the remaining WETH to LQTY
        IERC20(rewardToken()).safeApprove(universalLiquidator(), 0);
        IERC20(rewardToken()).safeApprove(
            universalLiquidator(),
            remainingRewardBalance
        );
        ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
            remainingRewardBalance,
            1,
            address(this),
            storedLiquidationDexes[weth][lqty],
            storedLiquidationPaths[weth][lqty]
        );
    }
}
