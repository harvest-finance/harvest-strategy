pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../../base/StrategyBase.sol";
import "../../base/interface/IVault.sol";

import "./interface/IDodoMine.sol";
import "./interface/IDodoV2Proxy02.sol";

contract DodoStrategyMainnet_USDT_USDC_USDT is StrategyBase {
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public dodo = address(0x43Dfc4159D86F3A37A5A4B3D4580b888ad7d4DDd);
    address public usdt = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    // DODO V2 router
    address public dodoV2Router =
        address(0xa356867fDCEa8e71AEaF87805808803806231FdC);

    // DODO approve contract
    address public dodoApprove =
        address(0xCB859eA579b28e02B87A1FDE08d087ab9dbE5149);

    // USDT/USDC pair on DODO V1
    address public dodoV1UsdtUsdcPair =
        address(0xC9f93163c99695c6526b799EbcA2207Fdf7D61aD);

    // USDT LP for USDT/USDC pair on DODO V1
    address public dodoV1UsdtUsdcUsdtLp =
        address(0x50b11247bF14eE5116C855CDe9963fa376FceC86);

    // DODO/USDT pair on DODO V1
    address public dodoV1DodoUsdtPair =
        address(0x8876819535b48b551C9e97EBc07332C7482b4b2d);

    // DODO Mine V1
    address public rewardPool =
        address(0xaeD7384F03844Af886b830862FF0a7AFce0a632C);

    // Flag for disabling selling for simplified emergency exit
    bool public sell = true;
    // Minimum amount of DODO to get liquidated
    uint256 public sellFloor = 1e17;
    // Flag for disabling investing into the strategy
    bool public pausedInvesting = false;

    event ProfitsNotCollected(address token);
    event Liquidating(address token, uint256 amount);

    // ---------------- Constructor ----------------

    constructor(address _storage, address _vault)
        public
        StrategyBase(_storage, dodoV1UsdtUsdcUsdtLp, _vault, dodo, address(0))
    {
        require(
            IVault(_vault).underlying() == underlying,
            "Vault does not support the required underlying LP token"
        );

        // Don't mark the DODO token as unsalvagable in order to be able to liquidate externally
        unsalvagableTokens[dodo] = false;
        unsalvagableTokens[underlying] = true;
    }

    // ---------------- IStrategy methods ----------------

    /**
     * @dev Withdraws everything back to the vault.
     */
    function withdrawAllToVault() public restricted {
        if (rewardPool != address(0)) {
            exitRewardPool();
        }
        _liquidateReward();
        IERC20(underlying).safeTransfer(
            vault,
            IERC20(underlying).balanceOf(address(this))
        );
    }

    function withdrawToVault(uint256 amount) public restricted {
        // Typically there wouldn't be any coins here - however, this would
        // still be possible because of an emergency exit
        uint256 currentBalance = IERC20(underlying).balanceOf(address(this));

        if (amount > currentBalance) {
            // While we have the check above, we're still using SafeMath, just
            // for peace of mind (in case something gets changed in between)
            uint256 needToWithdraw = amount.sub(currentBalance);
            uint256 toWithdraw = Math.min(rewardPoolBalance(), needToWithdraw);
            IDodoMine(rewardPool).withdraw(underlying, toWithdraw);
        }

        IERC20(underlying).safeTransfer(vault, amount);
    }

    /**
     * @dev Note that we currently don't have a mechanism here to include
     *      the accrued rewards.
     */
    function investedUnderlyingBalance() external view returns (uint256) {
        if (rewardPool == address(0)) {
            return IERC20(underlying).balanceOf(address(this));
        }
        // Add the amount locked in the reward pool and the amount that resides in this contract
        // (both are in the units of "underlying")
        // The second part is needed because of the emergency exit mechanism, which would break
        // the assumption that all funds are inside the reward pool
        return
            rewardPoolBalance().add(
                IERC20(underlying).balanceOf(address(this))
            );
    }

    /**
     * @dev Governance can claim coins that are somehow transferred into the contract
     *      (eg. by mistake). Note that the underlying LP token is not salvagable.
     */
    function salvage(
        address recipient,
        address token,
        uint256 amount
    ) external onlyGovernance {
        // Make sure governance cannot come in and take away the invested tokens
        require(
            !unsalvagableTokens[token],
            "Token is defined as non-salvagable"
        );
        IERC20(token).safeTransfer(recipient, amount);
    }

    function depositArbCheck() public view returns (bool) {
        return true;
    }

    /**
     * @dev Get the reward, sell it in exchange for the underlying, invest what you got.
     *      It's not much, but it's honest work.
     */
    function doHardWork() external restricted {
        // Add this check here as well for gas efficiency
        require(!pausedInvesting, "Investing is paused");

        exitRewardPool();
        _liquidateReward();
        investAllUnderlying();
    }

    // ---------------- Governance-only methods ----------------

    /**
     * @dev In case there are issues with the pool or underlying asset,
     *      governance can still trigger an emergency exit.
     */
    function emergencyExit() public onlyGovernance {
        emergencyExitRewardPool();
        pausedInvesting = true;
    }

    /**
     * @dev Resumes the ability to invest into the underlying rewards pool.
     */
    function continueInvesting() public onlyGovernance {
        pausedInvesting = false;
    }

    /**
     * @dev Can completely disable liquidation of DODO rewards. This can be
     *      useful in case of emergency exits.
     */
    function setSell(bool _sell) public onlyGovernance {
        sell = _sell;
    }

    /**
     * @dev Set the minimum amount of DODO needed to trigger a sale (for a liquidation).
     */
    function setSellFloor(uint256 _sellFloor) public onlyGovernance {
        sellFloor = _sellFloor;
    }

    // ---------------- Internal methods ----------------

    function rewardPoolBalance() internal view returns (uint256 balance) {
        uint256 poolId = IDodoMine(rewardPool).getPid(underlying);
        (balance, ) = IDodoMine(rewardPool).userInfo(poolId, address(this));
    }

    function enterRewardPool() internal {
        require(!pausedInvesting, "Investing is paused");

        uint256 currentBalance = IERC20(underlying).balanceOf(address(this));
        IERC20(underlying).safeApprove(rewardPool, 0);
        IERC20(underlying).safeApprove(rewardPool, currentBalance);
        IDodoMine(rewardPool).deposit(underlying, currentBalance);
    }

    function exitRewardPool() internal {
        uint256 balance = rewardPoolBalance();
        if (balance != 0) {
            IDodoMine(rewardPool).withdraw(underlying, balance);
        }
    }

    function emergencyExitRewardPool() internal {
        uint256 balance = rewardPoolBalance();
        if (balance != 0) {
            IDodoMine(rewardPool).emergencyWithdraw(underlying);
        }
    }

    function investAllUnderlying() internal {
        // This check is needed because the reward pool might revert on empty stakes
        if (IERC20(underlying).balanceOf(address(this)) > 0) {
            enterRewardPool();
        }
    }

    function _liquidateReward() internal {
        uint256 rewardBalance = IERC20(rewardToken).balanceOf(address(this));

        // Profits can be disabled for possible simplified and rapid exit
        if (!sell || rewardBalance < sellFloor) {
            emit ProfitsNotCollected(rewardToken);
            return;
        }

        notifyProfitInRewardToken(rewardBalance);
        uint256 remainingRewardBalance =
            IERC20(rewardToken).balanceOf(address(this));

        if (remainingRewardBalance == 0) {
            return;
        }

        IERC20(rewardToken).safeApprove(dodoApprove, 0);
        IERC20(rewardToken).safeApprove(dodoApprove, remainingRewardBalance);

        address[] memory dodoV1Pairs = new address[](1);
        dodoV1Pairs[0] = dodoV1DodoUsdtPair;

        // Swap DODO reward for USDT
        IDodoV2Proxy02(dodoV2Router).dodoSwapV1(
            rewardToken,
            usdt,
            remainingRewardBalance,
            1,
            dodoV1Pairs,
            0,
            false,
            block.timestamp
        );

        uint256 usdtBalance = IERC20(usdt).balanceOf(address(this));

        IERC20(usdt).safeApprove(dodoApprove, 0);
        IERC20(usdt).safeApprove(dodoApprove, usdtBalance);

        // Provide the new USDT as liquidity to get more underlying
        IDodoV2Proxy02(dodoV2Router).addLiquidityToV1(
            dodoV1UsdtUsdcPair,
            usdtBalance,
            0,
            1,
            0,
            0,
            block.timestamp
        );
    }
}
