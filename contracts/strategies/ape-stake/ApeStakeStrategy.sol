pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/upgradability/BaseUpgradeableStrategy.sol";

import "./interfaces/IApeCoinStaking.sol";

contract ApeStakeStrategy is IStrategy, BaseUpgradeableStrategy {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant APE = address(0x4d224452801ACEd8B2F0aebE155379bb5D594381);

    constructor() public BaseUpgradeableStrategy() {
    }

    /* ========== Initialize ========== */

    function initializeBaseStrategy(
        //  "__" for storage because we shadow _storage from GovernableInit
        address __storage,
        address _vault,
        address _rewardPool
    ) public initializer {
        BaseUpgradeableStrategy.initialize({
            _storage: __storage,
            _underlying: APE,
            _vault: _vault,
            _rewardPool: _rewardPool,
            _rewardToken: APE,
            _profitSharingNumerator: 300,
            _profitSharingDenominator: 1000,
            _sell: true,
            _sellFloor: 0,
            _implementationChangeDelay: 12 hours
        });
    }

    /* ========== View ========== */

    function depositArbCheck() public view returns (bool) {
        return true;
    }

    function unsalvagableTokens(address token) public view returns (bool) {
        return (token == rewardToken() || token == underlying());
    }

    function investedUnderlyingBalance() public view returns (uint256) {
        return _rewardPoolBalance().add(IERC20(underlying()).balanceOf(address(this)));
    }

    /* ========== Internal View ========== */

    function _rewardPoolBalance() internal view returns (uint256) {
        IApeCoinStaking.Position memory position = IApeCoinStaking(rewardPool()).addressPosition(address(this));
        return position.stakedAmount;
    }

    /* ========== Internal ========== */

    function _investAllUnderlying() internal {
        uint256 underlyingBalance = IERC20(underlying()).balanceOf(address(this));
        IERC20(underlying()).safeApprove(rewardPool(), 0);
        IERC20(underlying()).safeApprove(rewardPool(), underlyingBalance);
        IApeCoinStaking(rewardPool()).depositSelfApeCoin(underlyingBalance);
    }

    function _claimRewards() internal {
        IApeCoinStaking(rewardPool()).claimSelfApeCoin();
    }

    function _liquidateReward() internal {
        uint256 rewardBalanceBefore = IERC20(rewardToken()).balanceOf(address(this));
        _claimRewards();
        uint256 rewardBalanceAfter = IERC20(rewardToken()).balanceOf(address(this));
        uint256 claimed = rewardBalanceAfter.sub(rewardBalanceBefore);

        if (!sell() || claimed < sellFloor()) {
            // Profits can be disabled for possible simplified and rapid exit
            emit ProfitsNotCollected(sell(), claimed < sellFloor());
            return;
        }

        // Since underlyingToken and rewardToken are same as APE
        // Don't do any swap here, just nofity the profit
        notifyProfitInRewardToken(claimed);
    }

    /* ========== External ========== */

    function withdrawAllToVault() public restricted {
        _claimRewards();
        IApeCoinStaking(rewardPool()).withdrawSelfApeCoin(_rewardPoolBalance());
        IERC20(underlying()).safeTransfer(vault(), IERC20(underlying()).balanceOf(address(this)));
    }

    function withdrawToVault(uint256 amount) external restricted {
        uint256 strategyBalance = IERC20(underlying()).balanceOf(address(this));

        if (amount > strategyBalance) {
            uint256 amountToWithdraw = amount.sub(strategyBalance);
            uint256 poolBalance = _rewardPoolBalance(); 
            
            if(amountToWithdraw > poolBalance) {
                amountToWithdraw = poolBalance;
            }
            IApeCoinStaking(rewardPool()).withdrawSelfApeCoin(amountToWithdraw);
            IERC20(underlying()).safeTransfer(vault(), amountToWithdraw);
        } else {
            IERC20(underlying()).safeTransfer(vault(), amount);
        }
    }

    function salvage(
        address recipient,
        address token,
        uint256 amount
    ) external onlyControllerOrGovernance {
        // To make sure that governance cannot come in and take away the coins
        require(!unsalvagableTokens(token), "token is defined as not salvagable");
        IERC20(token).safeTransfer(recipient, amount);
    }

    /*
     *   Get the reward, sell it in exchange for underlying, invest what you got.
     *   It's not much, but it's honest work.
     *
     *   Note that although `onlyNotPausedInvesting` is not added here,
     *   calling `investAllUnderlying()` affectively blocks the usage of `doHardWork`
     *   when the investing is being paused by governance.
     */
    function doHardWork() external onlyNotPausedInvesting restricted {
        _liquidateReward();
        _investAllUnderlying();
    }

    function setSell(bool s) external onlyGovernance {
        _setSell(s);
    }

    function setSellFloor(uint256 floor) external onlyGovernance {
        _setSellFloor(floor);
    }

    function finalizeUpgrade() external onlyGovernance {
        _finalizeUpgrade();
    }
}