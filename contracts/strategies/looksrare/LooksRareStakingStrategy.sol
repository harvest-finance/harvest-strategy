pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../base/interface/uniswap/IUniswapV2Pair.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/upgradability/BaseUpgradeableStrategyUL.sol";
import "./interface/IFeeSharingSystem.sol";

import "hardhat/console.sol";

contract LooksRareStakingStrategy is IStrategy, BaseUpgradeableStrategyUL {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant uniswapRouterV2 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  constructor() public BaseUpgradeableStrategyUL() {
  }

  function initializeBaseStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    address _rewardToken
  ) public initializer {

    BaseUpgradeableStrategyUL.initialize(
      _storage,
      _underlying,
      _vault,
      _rewardPool,
      _rewardToken,
      300,  // profit sharing numerator
      1000, // profit sharing denominator
      true, // sell
      0, // sell floor
      12 hours, // implementation change delay
      address(0x7882172921E99d590E097cD600554339fBDBc480) //UL Registry
    );

    address _lpt = IFeeSharingSystem(rewardPool()).rewardToken();
    require(_lpt == _rewardToken, "Pool Info does not match rewardToken");
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  function rewardPoolBalance() internal view returns (uint256 bal) {
      (bal,,) = IFeeSharingSystem(rewardPool()).userInfo(address(this));
  }

  function exitRewardPool() internal {
      uint256 stakedBalance = rewardPoolBalance();
      if (stakedBalance != 0) {
          // bool flag param for claiming reward tokens set to true
          IFeeSharingSystem(rewardPool()).withdrawAll(true);
      }
  }

  function emergencyExitRewardPool() internal {
    uint256 stakedBalance = rewardPoolBalance();
    if (stakedBalance != 0) {
        // bool flag param for claiming reward tokens set to false
        IFeeSharingSystem(rewardPool()).withdrawAll(false);
    }
  }

  function unsalvagableTokens(address token) public view returns (bool) {
    return (token == rewardToken() || token == underlying());
  }

  function enterRewardPool() internal {
    uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));
    IERC20(underlying()).safeApprove(rewardPool(), 0);
    IERC20(underlying()).safeApprove(rewardPool(), entireBalance);

    // bool flag param for claiming reward tokens set to false
    IFeeSharingSystem(rewardPool()).deposit(entireBalance, false);
  }

  /*
  *   In case there are some issues discovered about the pool or underlying asset
  *   Governance can exit the pool properly
  *   The function is only used for emergency to exit the pool
  */
  function emergencyExit() public onlyGovernance {
    emergencyExitRewardPool();
    _setPausedInvesting(true);
  }

  /*
  *   Resumes the ability to invest into the underlying reward pools
  */
  function continueInvesting() public onlyGovernance {
    _setPausedInvesting(false);
  }

  function _liquidateReward() internal {
    uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    if (!sell() || rewardBalance < sellFloor()) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected(sell(), rewardBalance < sellFloor());
      return;
    }

    notifyProfitInRewardToken(rewardBalance);
    uint256 remainingRewardBalance = IERC20(rewardToken()).balanceOf(address(this));

    if (remainingRewardBalance <= 0) {
      return;
    }

    IERC20(rewardToken()).safeApprove(universalLiquidator(), 0);
    IERC20(rewardToken()).safeApprove(universalLiquidator(), remainingRewardBalance);

    // we can accept 1 as minimum because this is called only by a trusted role
    ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
      remainingRewardBalance,
      1,
      address(this), // target
      storedLiquidationDexes[rewardToken()][underlying()],
      storedLiquidationPaths[rewardToken()][underlying()]
    );
  }

  /*
  *   Stakes everything the strategy holds into the reward pool
  */
  function investAllUnderlying() internal onlyNotPausedInvesting {
    if(IERC20(underlying()).balanceOf(address(this)) > 0) {
      enterRewardPool();
    }
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawAllToVault() public restricted {
    if (address(rewardPool()) != address(0)) {
      exitRewardPool();
    }
    _liquidateReward();
    IERC20(underlying()).safeTransfer(vault(), IERC20(underlying()).balanceOf(address(this)));
  }

  /*
  *   Withdraws the amount for the asset to the vault
  */
  function withdrawToVault(uint256 amount) public restricted {
    // Typically there wouldn't be any amount here
    // however, it is possible because of the emergencyExit
    uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));

    if(amount > entireBalance){
      // While we have the check above, we still using SafeMath below
      // for the peace of mind (in case something gets changed in between)
      uint256 needToWithdrawLOOKS = amount.sub(entireBalance);

      // convert amount of underlying to withdraw to shares price
      uint256 oneShareInLOOKS = IFeeSharingSystem(rewardPool()).calculateSharePriceInLOOKS();
      uint256 needToWithdrawShares = needToWithdrawLOOKS.div(oneShareInLOOKS);

      uint256 sharesToWithdraw = Math.min(rewardPoolBalance(), needToWithdrawShares);

      // bool flag param for claiming reward tokens set to false
      IFeeSharingSystem(rewardPool()).withdraw(sharesToWithdraw, false);
    }

    uint256 underlyingBalance = IERC20(underlying()).balanceOf(address(this));

    // recalculate to improve accuracy
    uint256 underlyingAmountToWithdraw = Math.min(amount, underlyingBalance);

    IERC20(underlying()).safeTransfer(vault(), underlyingAmountToWithdraw);
  }

  /*
  *   Note that we currently do not have a mechanism here to include the
  *   amount of reward that is accrued.
  */
  function investedUnderlyingBalance() external view returns (uint256) {
    if (rewardPool() == address(0)) {
      return IERC20(underlying()).balanceOf(address(this));
    }

    // using the calculateSharePriceInLOOKS instead of the calculateSharesValueInLOOKS is more exact
    uint256 oneShareInLOOKS = IFeeSharingSystem(rewardPool()).calculateSharePriceInLOOKS();
    uint256 balanceInLOOKS = rewardPoolBalance().mul(oneShareInLOOKS);

    // Adding the amount locked in the reward pool and the amount that is somehow in this contract
    // both are in the units of "underlying"
    // The second part is needed because there is the emergency exit mechanism
    // which would break the assumption that all the funds are always inside of the reward pool
    return balanceInLOOKS.add(IERC20(underlying()).balanceOf(address(this)));
  }

  /*
  *   Governance or Controller can claim coins that are somehow transferred into the contract
  *   Note that they cannot come in take away coins that are used and defined in the strategy itself
  */
  function salvage(address recipient, address token, uint256 amount) external onlyControllerOrGovernance {
     // To make sure that governance cannot come in and take away the coins
    require(!unsalvagableTokens(token), "token is defined as not salvagable");
    IERC20(token).safeTransfer(recipient, amount);
  }

  /*
  *   Get the reward, sell it in exchange for underlying, invest what you got.
  *   It's not much, but it's honest work.
  */
  function doHardWork() external onlyNotPausedInvesting restricted {
    uint256 pendingRewards = IFeeSharingSystem(rewardPool()).calculatePendingRewards(address(this));
    console.log("doing hardwork, pending rewards in WETH:", pendingRewards);
    if (pendingRewards > 0) {
      IFeeSharingSystem(rewardPool()).harvest();
    }
    _liquidateReward();
    investAllUnderlying();
  }

  /**
  * Can completely disable claiming UNI rewards and selling. Good for emergency withdraw in the
  * simplest possible way.
  */
  function setSell(bool s) public onlyGovernance {
    _setSell(s);
  }

  /**
  * Sets the minimum amount of CRV needed to trigger a sale.
  */
  function setSellFloor(uint256 floor) public onlyGovernance {
    _setSellFloor(floor);
  }

  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
  }
}
