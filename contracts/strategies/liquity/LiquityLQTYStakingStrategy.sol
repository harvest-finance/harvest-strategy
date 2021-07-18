pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../../base/upgradability/BaseUpgradeableStrategy.sol";

import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "./interface/ICurveMetapool.sol";
import "./interface/ILQTYStaking.sol";
import "./interface/ISwapRouter.sol";

contract LiquityLQTYStakingStrategy is IStrategy, BaseUpgradeableStrategy {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // LUSD token
    address public constant lusd =
        address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);

    // LQTY token
    address public constant lqty =
        address(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D);

    // USDC token
    address public constant usdc =
        address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // WETH token
    address public constant weth =
        address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // LUSD/3CRV pair on Curve
    address public constant lusd3CrvPair =
        address(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);

    // USDC/ETH pair on UniswapV3
    address public constant usdcEthPair =
        address(0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8);

    // LQTY staking
    address public constant lqtyStaking =
        address(0x4f9Fbb3f1E99B56e0Fe2892e623Ed36A76Fc605d);

    // UniswapV3 router
    address public constant uniswapV3Router =
        address(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    // ---------------- Constructor ----------------

    constructor() public BaseUpgradeableStrategy() {}

    // ---------------- Initializer ----------------

    function initializeStrategy(address _storage, address _vault)
        public
        initializer
    {
        BaseUpgradeableStrategy.initialize(
            _storage,
            lqty,
            _vault,
            lqtyStaking,
            // Rewards are actually given in LUSD and ETH. However, for
            // improved liquidity (for LUSD) and usage simplification,
            // we swap the rewards to USDC and use USDC as a reward token.
            usdc,
            300, // Profit sharing numerator
            1000, // Profit sharing denominator
            true, // Sell
            1e6, // Sell floor
            12 hours // Implementation change delay
        );
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
        uint256 ethBalance = address(this).balance;

        // Liquidate the LUSD rewards to USDC
        if (lusdBalance > 0) {
            IERC20(lusd).safeApprove(lusd3CrvPair, 0);
            IERC20(lusd).safeApprove(lusd3CrvPair, lusdBalance);
            ICurveMetapool(lusd3CrvPair).exchange_underlying(
                0,
                2,
                lusdBalance,
                1
            );
        }

        // Liquidate the ETH rewards to USDC
        if (ethBalance > 0) {
            ISwapRouter(uniswapV3Router).exactInputSingle.value(ethBalance)(
                ISwapRouter.ExactInputSingleParams(
                    weth,
                    usdc,
                    500,
                    address(this),
                    block.timestamp,
                    ethBalance,
                    1,
                    0
                )
            );
        }

        // At this point, both LUSD and ETH rewards were swapped for USDC,
        // which we now handle as the reward token
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

        // Liquidate the remaining USDC to LQTY
        IERC20(usdc).safeApprove(uniswapV3Router, 0);
        IERC20(usdc).safeApprove(uniswapV3Router, remainingRewardBalance);
        ISwapRouter(uniswapV3Router).exactInput(
            ISwapRouter.ExactInputParams(
                abi.encodePacked(usdc, uint24(500), weth, uint24(3000), lqty),
                address(this),
                block.timestamp,
                remainingRewardBalance,
                1
            )
        );
    }
}
