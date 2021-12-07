pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../../../base/upgradability/BaseUpgradeableStrategyUL.sol";

import "../../../base/interface/IStrategy.sol";
import "../../../base/interface/IVault.sol";
import "../../../base/interface/weth/Weth9.sol";
import "../interface/IDInterest.sol";
import "../interface/IxMph.sol";
import "../interface/IVesting.sol";

contract EightyEightMphStrategy is IStrategy, BaseUpgradeableStrategyUL {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant mph = address(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    address public constant xmph = address(0x1702F18c1173b791900F81EbaE59B908Da8F689b);
    address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
    bytes32 internal constant _POTPOOL_SLOT = 0x7f4b50847e7d7a4da6a6ea36bfb188c77e9f093697337eb9a876744f926dd014;

    // strategy vars that should be reset on upgrade
    // we do not want to bring the deposit related vars along because they are connected to the address of this strategy.
    uint256 public depositMaturity = 0;
    /**
     * The depositId will be automatically set at the first time the strategy deposits into 88mph
     * subsequent deposits use a "top up deposit" method rather than creating a new one
     * This is crucial because 88mph waives the early withdrawal fee only for this specific depositId
     */
    uint64 public depositId = 0;


    // ---------------- Constructor ----------------

    constructor() public BaseUpgradeableStrategy() {
        assert(_POTPOOL_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.potPool")) - 1));
    }

    // ---------------- Initializer ----------------

    function initializeBaseStrategy(
        address _storage,
        address _vault,
        address _underlying,
        address _rewardPool,
        address _potPool
    ) public initializer {
        require(IDInterest(_rewardPool).stablecoin() == underlying(), "Reward pool asset does not match underlying");
        
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

        setAddress(_POTPOOL_SLOT, _potPool);
    }

    // ---------------- IStrategy methods ----------------
    function unsalvagableTokens(address token) public view returns (bool) {
        return (token == rewardToken() || token == underlying());
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
        emergencyExitRewardPool();
    }

    function emergencyExitRewardPool() {
        // don't claim rewards, just withdraw. Use maxInt to withdraw all
        uint256 maxInt = 2**256 - 1; // see https://forum.openzeppelin.com/t/using-the-maximum-integer-in-solidity/3000
        bool early = block.timestamp < depositMaturity; // withdrawing after maturation​
        IDInterest(rewardPool()).withdraw(depositID, maxInt, early);
    }

    /**
     * Used to manually rollover a deposit to a new maturity date.
     * doHardWork can be triggered afterwards again if it failed previously because maturity was about to be reached
     */
    function rolloverDeposit() public restricted {
        // Attention: it is imperative that 88mph waives the early withdrawal fee for the new depositID!
        depositMaturity = block.timestamp + 365 days;
        (depositId,) = IDInterest(rewardPool()).rolloverDeposit(depositId(), depositMaturity);
    }

    function setPotPool(address _value) public onlyGovernance {
        require(potPool() == address(0), "PotPool already set");
        setAddress(_POTPOOL_SLOT, _value);
    }

    function potPool() public view returns (address) {
        return getAddress(_POTPOOL_SLOT);
    }

    /**
     * @dev Resumes the ability to invest into the underlying rewards pool.
     */
    function continueInvesting() public onlyGovernance {
        _setPausedInvesting(false);
    }

    /**
     * @dev Can completely disable liquidation of rewards. This can be
     *      useful in case of emergency exits.
     */
    function setSell(bool _sell) public onlyGovernance {
        _setSell(_sell);
    }

    /**
     * @dev Set the minimum amount of reward token needed to trigger a sale (for a liquidation).
     */
    function setSellFloor(uint256 _sellFloor) public onlyGovernance {
        setSellFloor(_sellFloor);
    }

    function finalizeUpgrade() external onlyGovernance {
        // Note we don't have to transfer the vesting NFT because all rewards are claimed at the upgrade

        _finalizeUpgrade();

        // Reset the liquidation paths - they need to be reset manually
        storedLiquidationPaths[usdc][weth] = new address[](0);
        storedLiquidationDexes[usdc][weth] = new bytes32[](0);
        storedLiquidationPaths[weth][lqty] = new address[](0);
        storedLiquidationDexes[weth][lqty] = new bytes32[](0);
    }

    // ---------------- Internal methods ----------------

    function rewardPoolBalance() internal view returns (uint256 balance) {
        // todo
        balance = IDInterest(rewardPool()).stakes(address(this));
    }

    function claimRewards() internal {
        if (rewardPoolBalance() <= 0) {
            return;
        }
        // get vesting id
        uint64 vestingId = IVesting(vesting()).depositIDToVestID[rewardPool()][depositID];
        // claim
        IVesting(vesting()).withdraw(vestingId);
    }

    function enterRewardPool() internal {
        uint256 currentBalance = IERC20(underlying()).balanceOf(address(this));
        if(currentBalance <= 0) {
            return;
        }

        if(depositId() == 0) {
            // create a new deposit to get a depositId. Use maximum possible maturity (1 year)
            depositMaturity = block.timestamp + 365 days;
            IERC20(underlying()).approve(rewardPool(), 0);
            IERC20(underlying()).approve(rewardPool(), entireBalance);
            depositId = IDInterest(rewardPool()).deposit(currentBalance, maturationTimestamp);
            // ensure depositId is valid
            require(depositId > 0, "depositId not set after deposit");
        } else {
            // check if current depsot is about to reach maturity
            if(block.timestamp > (depositMaturity - 14 days)) {
                // time to roll over the deposit to a new depositId with extended maturity
                // we revert here because we want this process to be kicked off manually.
                // it is imperative that the withdrawal fee is waived for the new depositId - which we can not do
                // If that is not done, this strategy will start losing money for depositors.
                revert("Deposit must be rolled over. ATTENTION: ENSURE WITHDRAWAL FEE IS WAIVED FOR NEW DEPOSITID");
            } 
            
            // top up the existing deposit with waived early withdrawal fee
            IDInterest(rewardPool()).topupDeposit(depositId(), currentBalance);
        }

    }

    function exitRewardPool() internal {
        claimRewards();

        uint256 maxInt = 2**256 - 1; // see https://forum.openzeppelin.com/t/using-the-maximum-integer-in-solidity/3000
        bool early = block.timestamp < depositMaturity; // withdrawing after maturation​
        IDInterest(rewardPool()).withdraw(depositID, maxInt, early);
    }

    /**
     * @dev Invests everything the strategy holds into the reward pool.
     */
    function investAllUnderlying() internal onlyNotPausedInvesting {
        // This check is needed for avoiding reverts in case we invest 0
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

        _rewardsToStaked();
        _rewardsToRewardToken();
        _rewardsShareProfit();
        _rewardsToUnderlying();

        // todos:

        stake: rewardBalance * stakingAmountPercentage * (profitSharingDenumerator - profitSharingNumerator)
        takeProfit: rewardBalance * profitSharingNumerator / stakingAmountPercentage * (profitSharingDenumerator - profitSharingNumerator)
        rest reinvest 
    }

    function _rewardsToStaked() internal {
        // get rewards balance
        uint256 mphBalance = IERC20(mph).balanceOf(address(this));
        if(mphBalance <= 0) {
            return;
        }
        // 1. stake MPH to xMPH
        IxMph(xMph).deposit(mphBalance);

        // 2. distribute xMPH via pot pool
        uint256 xMphBalance = IERC20(xMph).balanceOf(address(this));
        IERC20(address(this)).safeTransfer(potPool(), xMphBalance);
        PotPool(potPool()).notifyTargetRewardAmount(address(this), xMphBalance);
    }

    function _rewardsToRewardToken() internal {
        uint256 mphBalance = IERC20(mph).balanceOf(address(this));
        if(mphBalance <= 0) {
            return;
        }

        // liquidate MPH to rewardToken
        IERC20(mph).safeApprove(universalLiquidator(), 0);
        IERC20(mph).safeApprove(universalLiquidator(), mphBalance);
        ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
            mphBalance,
            1,
            address(this),
            storedLiquidationDexes[mph][rewardToken()],
            storedLiquidationPaths[mph][rewardToken()]
        );
    }

    function _rewardsShareProfit() internal {
        // At this point all rewards have been partially staked alread and the rest swapped to reward token
        uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));

        // Profits can be disabled for possible simplified and rapid exit
        if (rewardBalance < sellFloor()) {
            emit ProfitsNotCollected(sell(), rewardBalance < sellFloor());
            return;
        }

        notifyProfitInRewardToken(rewardBalance);
    }

    function _rewardsToUnderlying() internal {
        uint256 remainingRewardBalance = IERC20(rewardToken()).balanceOf(
            address(this)
        );

        if (remainingRewardBalance <= 0) {
            return;
        }

        // Liquidate the remaining reward token balance to underlying
        IERC20(rewardToken()).safeApprove(universalLiquidator(), 0);
        IERC20(rewardToken()).safeApprove(
            universalLiquidator(),
            remainingRewardBalance
        );
        ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
            remainingRewardBalance,
            1,
            address(this),
            storedLiquidationDexes[rewardToken()][underlying()],
            storedLiquidationPaths[rewardToken()][underlying()]
        );
    }
}
