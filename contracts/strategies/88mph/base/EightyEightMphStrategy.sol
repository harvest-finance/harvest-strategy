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
import "../interface/IDInterestLens.sol";
import "../interface/IxMph.sol";
import "../interface/IVesting.sol";

contract EightyEightMphStrategy is IStrategy, BaseUpgradeableStrategyUL {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant mph = address(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    address public constant xmph = address(0x1702F18c1173b791900F81EbaE59B908Da8F689b);
    address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address public constant dInterestLens = address(0x8Fea3e2d505AAe5AF39186dC6E0d5DDBa49e751D);

    // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
    bytes32 internal constant _POTPOOL_SLOT = 0x7f4b50847e7d7a4da6a6ea36bfb188c77e9f093697337eb9a876744f926dd014;
    bytes32 internal constant _XMPH_DISTRIBUTION_PERCENTAGE = 0x1b378bd6fdddc18469a043a7f60ed057610812f568a7eda4d5bdbfef720b0a60;

    // strategy vars that should not be ported on upgrade
    /**
     * The depositId will be automatically set at the first time the strategy deposits into 88mph
     * subsequent deposits use a "top up deposit" method rather than creating a new one
     * This is crucial because 88mph waives the early withdrawal fee only for this specific depositId
     */
    uint64 public depositId = 0;


    // ---------------- Constructor ----------------

    constructor() public BaseUpgradeableStrategy() {
        assert(_POTPOOL_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.potPool")) - 1));
        assert(_XMPH_DISTRIBUTION_PERCENTAGE == bytes32(uint256(keccak256("eip1967.strategyStorage.xMphDistributionPercentage")) - 1));
    }

    // ---------------- Initializer ----------------

    function initializeBaseStrategy(
        address _storage,
        address _vault,
        address _underlying,
        address _rewardPool,
        address _potPool,
        uint256 _xMphDistributionPercentage
    ) public initializer {
        require(IDInterest(_rewardPool).stablecoin() == underlying(), "Reward pool asset does not match underlying");
        
        BaseUpgradeableStrategyUL.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            weth,
            300,  // profit sharing numerator
            1000, // profit sharing denominator
            true, // sell
            0, // sell floor
            12 hours, // implementation change delay
            address(0x7882172921E99d590E097cD600554339fBDBc480) //UL Registry
        );

        setAddress(_POTPOOL_SLOT, _potPool);
        setUint256(_XMPH_DISTRIBUTION_PERCENTAGE, _xMphDistributionPercentage);
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

            // get deposit data
            (uint264 virtualTokenTotalSupply,,,, uint64 depositMaturity,) = IDInterest(rewardPool()).getDeposit(depositId);

            // check if we reached maturity
            bool early = block.timestamp <= depositMaturity;

            uint256 withdrawVirtualAmount = amount;

            if(early) {
                // before maturation, virtualTokenAmount passed in to IDInterest.withdraw does not match underlying 1:1
                // to get the ratio of underlying to virtualToken, we can use virtualTokenTotalSupply to rewardPoolBalance()
                uint256 withdrawVirtualAmount = needToWithdraw.mul(virtualTokenTotalSupply).div(rewardPoolBalance());
            } 
            // after maturation virtualAmount = 1:1 with underlying, so no else statement needed here

            uint256 toWithdraw = Math.min(virtualTokenTotalSupply, withdrawVirtualAmount);

            IDInterest(rewardPool()).withdraw(depositId, toWithdraw, early);
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
        bool early = block.timestamp < depositMaturity(); // withdrawing before or after maturation​
        IDInterest(rewardPool()).withdraw(depositID, maxInt, early);
    }

    /**
     * Use to manually rollover a deposit to a new maturity date.
     * This will create a new deposit using the principal + fixed-rate yield of the old deposit.
     * doHardWork can be triggered afterwards again if it failed previously because maturity was about to be reached
     */
    function rolloverDeposit(bool confirmWithdrawalFeeWillBeWaived) public restricted {
        // Attention: it is imperative that 88mph waives the early withdrawal fee for the new depositID!
        // Fail if confirm flag is not passed in as true to ensure whoever triggers this understands that it must be arranged 
        // for the withdrawal fee to be waived for the new deposit Id
        require(confirmWithdrawalFeeWillBeWaived, "Withdrawal fee arrangement confirmation missing");

        // ensure deposit has reached maturity to get the fixed yield rate
        require(block.timestamp > depositMaturity(), "Deposit has not reached maturity yet");

        // fixed yield earnings are applied at rollover. They are added to the new deposit.
        // but we have no fair way of distributing it, and if we just add it to the new deposit 
        // some users might get lucky and some that just withdrew the day before are in a disadvantage.
        // so we deduct it as profit sharing fee.

        // 1. calculate the interest amount

        // get the deposit
        (uint264 virtualTokenTotalSupply, uint264 interestRate) = IDInterest(rewardPool()).getDeposit(depositId);

        // we calculate the interest amount the same way as IDInterestLens does it
        // see https://github.com/88mphapp/88mph-contracts/blob/5ab4ed0d4d4e83fd9a01e8f1ab5c4577b583d857/contracts/DInterestLens.sol#L49
        uint256 depositAmount = virtualTokenTotalSupply.div(interestRate + 10**18);
        uint256 interestAmount = virtualTokenTotalSupply.sub(depositAmount);

        // 2. rollover the deposit
        uint64 maturationTimestamp = block.timestamp + 365 days;
        (depositId,) = IDInterest(rewardPool()).rolloverDeposit(depositId, maturationTimestamp);

        require(depositId > 0, "depositId not set after rollover");

        // 3. withdraw the interestAmount from the deposit
        IDInterest(rewardPool()).withdraw(depositId, interestAmount, true);

        // 4. convert underlying principal to reward token
        _underlyingToRewardToken();

        // 5. take fixed yield interest gains as profit
        uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
        if (rewardBalance <= 0) {
            return;
        }

        // to take the full amount we have to adjust the numbers a bit that we pass in to the notifyProfitInRewardToken method
        // because in this situation we do not take a cut, we take the full fixed yield gains

        // formula : rewardBalance * profitSharingDenominator / profitSharingNumerator
        // e.g. 180 * 1000 / 300 = 180 * 10 / 3 = 1800 / 3 = 600
        // notifyProfitInRewardToken will take 30% of 600, which is 180 -> correct
        uint256 takeFullProfitBalance = rewardBalance * profitSharingDenominator() / profitSharingNumerator();

        notifyProfitInRewardToken(takeFullProfitBalance);
    }

    function setPotPool(address _value) public onlyGovernance {
        require(potPool() == address(0), "PotPool already set");
        setAddress(_POTPOOL_SLOT, _value);
    }

    function potPool() public view returns (address) {
        return getAddress(_POTPOOL_SLOT);
    }

    /**
     * Sets the percentage for the amount of rewards that will be distributed as xMPH to depositors (after fees)
     * e.g. value of 50%: first 30% profit sharing fee is deducted, so of the left over 70% of rewards, 50% are distributed
     * as xMPH, which would be 35% of the total rewards.
     */
    function setXMphDistributionPercentage(uint256 _value) public onlyGovernance {
        setUint256(_XMPH_DISTRIBUTION_PERCENTAGE, _value);
    }

    function xMphDistributionPercentage() public view returns (uint256) {
        return getUint256(_XMPH_DISTRIBUTION_PERCENTAGE);
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
        // Note we don't have to transfer the vesting NFT etc. because all rewards are claimed at the upgrade
        // fixed yield will be lost in the upgrading process however

        _finalizeUpgrade();

        // Reset the liquidation paths - they need to be reset manually
        storedLiquidationPaths[mph][rewardToken()] = new address[](0);
        storedLiquidationDexes[mph][rewardToken()] = new bytes32[](0);
        storedLiquidationPaths[rewardToken()][underlying()] = new address[](0);
        storedLiquidationDexes[rewardToken()][underlying()] = new bytes32[](0);
        storedLiquidationPaths[underlying()][rewardToken()] = new address[](0);
        storedLiquidationDexes[underlying()][rewardToken()] = new bytes32[](0);
    }

    // ---------------- Internal methods ----------------

    function rewardPoolBalance() internal view returns (uint256 balance) {
        uint256 maxInt = 2**256 - 1; // see https://forum.openzeppelin.com/t/using-the-maximum-integer-in-solidity/3000

        // we check for the maximum amount that we could withdraw after fees
        (balance, ) = IDInterestLens(dInterestLens).withdrawableAmountOfDeposit(IDInterest(rewardPool()), depositId, maxInt);

        // the withdrawableAmountOfDeposit method used of DInterestLens calculates the withdrawable amount based on the virtualTokenTotalSupply
        // of the deposit. the virtualTokenTotalSupply includes the interest amount that becomes available after maturation.
        // it does however only include this interest amount AFTER maturation.

        // We do not distribute the fixed yield earnings because there is no fair way to distribute them:
        // at time of withdrawal we can't predict how much interest will be earned at maturation
        // at time of rollover, lucky users would get the gains if they hit the maturation date, whilst others might miss it
        // even though those that miss it, might have been depositors for way longer.

        // Thus, for the rewardPoolBalance we never want to include the interest.
        // We have to handle two cases here, BEFORE and AFTER maturation.
        // - the rewardPoolBalance BEFORE maturation has been reached will be correct like this - no further action needed
        // - for the rewardPoolBalance AFTER maturation we have to subtract the interest amount 

        if(block.timestamp > depositMaturity()) {
            // maturity reached, we have to subtract the interest amount gains because we don't distribute those

            // get the deposit
            (uint264 virtualTokenTotalSupply, uint264 interestRate) = IDInterest(rewardPool()).getDeposit(depositId);

            // we calculate the interest amount the same way as IDInterestLens does it
            // see https://github.com/88mphapp/88mph-contracts/blob/5ab4ed0d4d4e83fd9a01e8f1ab5c4577b583d857/contracts/DInterestLens.sol#L49
            uint256 depositAmount = virtualTokenTotalSupply.div(interestRate + 10**18);
            uint256 interestAmount = virtualTokenTotalSupply.sub(depositAmount);

            // now we subtract this interest amount
            balance = balance.sub(interestAmount);
        }

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

        if(depositId == 0) {
            // create a new deposit to get a depositId. Use maximum possible maturity (1 year)
            uint64 maturationTimestamp = block.timestamp + 365 days;
            IERC20(underlying()).approve(rewardPool(), 0);
            IERC20(underlying()).approve(rewardPool(), entireBalance);
            depositId = IDInterest(rewardPool()).deposit(currentBalance, maturationTimestamp);
            // ensure depositId is valid
            require(depositId > 0, "depositId not set after deposit");
        } else {
            // check if current deposit has reached its maturity
            if(block.timestamp > depositMaturity()) {
                // time to roll over the deposit to a new depositId with extended maturity
                // we revert here because we want this process to be kicked off manually.
                // it is imperative that the withdrawal fee is waived for the new depositId - which we can not do
                // If that is not done, this strategy will start losing money for depositors.
                revert("Deposit must be rolled over. ATTENTION: ENSURE WITHDRAWAL FEE IS WAIVED FOR NEW DEPOSITID");
            } 
            
            // top up the existing deposit with waived early withdrawal fee
            IDInterest(rewardPool()).topupDeposit(depositId, currentBalance);
        }

    }

    function depositMaturity() internal returns(uint64 depositMaturity){
        (,,,, depositMaturity) = IDInterest(rewardPool).getDeposit(depositId);
    }

    function exitRewardPool() internal {
        claimRewards();

        uint256 maxInt = 2**256 - 1; // see https://forum.openzeppelin.com/t/using-the-maximum-integer-in-solidity/3000
        bool early = block.timestamp < depositMaturity(); // withdrawing after or before maturation​
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
    }

    function _rewardsToStaked() internal {
        // get rewards balance
        uint256 mphBalance = IERC20(mph).balanceOf(address(this));
        if(mphBalance <= 0) {
            return;
        }

        // formula to get the correct amount for staking takes into account that the profit sharing fee would have to be
        // deducted first. Converting all the rewards to rewardToken and then swapping them back to stake is however 
        // a waste of resources because some of the rewards are lost as fees and slippage during the swap. That's why we 
        // use this a little bit more complicated way with improved results.
        // formula: (rewardBalance * stakingAmountPercentage * (profitSharingDenumerator - profitSharingNumerator)) / 1000000
        // e.g. (200 * 500 * (1000 - 300)) / 1000000 ) = (200 * 500 * 700)  / 1000000 = 70000000 / 1000000 = 70.
        // 70 is 50% of 200 after the 30% profit sharing fee -> (200 - 60) / 2 = 70 -> correct
        uint256 amountToStake = mphBalance.mul(xMphDistributionPercentage())
                                          .mul((profitSharingDenumerator().sub(profitSharingNumerator())))
                                          .div(1000000);

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

        // profit is deducted from the rewards before anything else. In this strategy however it is smart to first 
        // execute staking and then swap to the reward token. Thus we have to calculate the initial value here that was 
        // present before doing the staking to take the correct cut for the profit sharing fee

        // e.g. if we would use the rewardBalance here, without any further calculations, we would take
        // 130 * 300 / 1000 = 13 * 3 = 39 (see notifyProfitInRewardToken method) as fees
        // which is wrong. the correct result must be
        // 200 * 300 / 1000 = 20 * 3 = 60
        // so we need to calculate the initial value present before staking

        // first, we calculate the percentage that the current reward balance represents of the whole amount present for staking
        // formula e.g. = 1000 - (500 * (1000 - 300) / 1000) = 1000 - (50 * 7) = 650
        uint256 percentageLeft = (1000).sub(
                                           xMphDistributionPercentage() // e.g. 500 
                                          .mul((profitSharingDenumerator().sub(profitSharingNumerator()))) // e.g. 1000 - 300 = 700
                                          .div(1000)
                                        );

        // based on the percentageLeft value we can now calculate the value that was present in rewards before staking
        // formula: rewardBalance * 1000 / percentageLeft
        // e.g. 130 * 1000 / 650 = 130 * 100 / 65 = 13000/65 = 200 -> correct
        uint256 initialRewardBalance = rewardBalance.mul(1000).div(percentageLeft);

        notifyProfitInRewardToken(initialRewardBalance);
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

    function _underlyingToRewardToken() internal {
        uint256 underlyingBalance = IERC20(underlying()).balanceOf(address(this));
        if(underlyingBalance <= 0) {
            return;
        }

        // liquidate underlying to rewardToken
        IERC20(underlying()).safeApprove(universalLiquidator(), 0);
        IERC20(underlying()).safeApprove(universalLiquidator(), underlyingBalance);
        ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
            underlyingBalance,
            1,
            address(this),
            storedLiquidationDexes[underlying()][rewardToken()],
            storedLiquidationPaths[underlying()][rewardToken()]
        );
    }
}
