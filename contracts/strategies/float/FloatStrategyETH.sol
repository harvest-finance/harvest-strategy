pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


import "./interface/IETHPhase2Pool.sol";
import "../../base/StrategyBase.sol";
import "../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../base/interface/weth/Weth9.sol";

contract FloatStrategyETH is StrategyBase, ReentrancyGuard {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  bool pausedInvesting = false; // When this flag is true, the strategy will not be able to invest. But users should be able to withdraw.
  IETHPhase2Pool public rewardPool;
  address public rewardToken;
  address public _weth;

  address[] public liquidationPath;

  // This is only used in `investAllUnderlying()`
  // The user can still freely withdraw from the strategy
  modifier onlyNotPausedInvesting() {
    require(!pausedInvesting, "Action blocked as the strategy is in emergency state");
    _;
  }

  constructor(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardToken,
    address _uniswapRouterAddress
  )
  StrategyBase(_storage, _underlying, _vault, _rewardToken, _uniswapRouterAddress)
  public {
    rewardToken = _rewardToken;
    _weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  /*
  *   In case there are some issues discovered about the pool or underlying asset
  *   Governance can exit the pool properly
  *   The function is only used for emergency to exit the pool
  */
  function emergencyExit() public onlyGovernance nonReentrant {
    rewardPool.exit();
    WETH9 weth = WETH9(address(_weth));
    weth.deposit.value(address(this).balance)();
    pausedInvesting = true;
  }

  /*
  *   Resumes the ability to invest into the underlying reward pools
  */

  function continueInvesting() public onlyGovernance {
    pausedInvesting = false;
  }

  /**
  * Sets the route for liquidating the reward token to the underlying token
  */
  function setLiquidationPath(address[] memory _newPath) public onlyGovernance {
    liquidationPath = _newPath;
  }

  // We assume that all the tradings can be done on Uniswap
  function _liquidateReward() internal {
    uint256 rewardAmount = IERC20(rewardToken).balanceOf(address(this));

    if (rewardAmount > 0 // we have tokens to swap
      && liquidationPath.length > 1 // and we have a route to do the swap
    ) {
      notifyProfitInRewardToken(rewardAmount);
      rewardAmount = IERC20(rewardToken).balanceOf(address(this));

      // we can accept 1 as minimum because this is called only by a trusted role
      uint256 amountOutMin = 1;

      IERC20(rewardToken).safeApprove(uniswapRouterV2, 0);
      IERC20(rewardToken).safeApprove(uniswapRouterV2, rewardAmount);

      IUniswapV2Router02(uniswapRouterV2).swapExactTokensForTokens(
        rewardAmount,
        amountOutMin,
        liquidationPath,
        address(this),
        block.timestamp
      );
    }
  }

  /*
  *   Stakes everything the strategy holds into the reward pool
  */
  function investAllUnderlying() internal onlyNotPausedInvesting nonReentrant {
    // this check is needed, because most of the SNX reward pools will revert if
    // you try to stake(0).

    uint256 underlyingBalance = IERC20(underlying).balanceOf(address(this));
    if(underlyingBalance > 0) {
      WETH9 weth = WETH9(address(_weth));
      weth.withdraw(underlyingBalance); // Unwrapping
      rewardPool.stake.value(underlyingBalance)(underlyingBalance);
    }
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawAllToVault() public restricted nonReentrant {
    if (address(rewardPool) != address(0)) {
      if (rewardPool.balanceOf(address(this)) > 0) {
        rewardPool.exit();
        WETH9 weth = WETH9(address(_weth));
        weth.deposit.value(address(this).balance)();
      }
    }
    _liquidateReward();
    if (IERC20(underlying).balanceOf(address(this)) > 0) {
      IERC20(underlying).safeTransfer(vault, IERC20(underlying).balanceOf(address(this)));
    }
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawToVault(uint256 amount) public restricted nonReentrant {
    // Typically there wouldn't be any amount here
    // however, it is possible because of the emergencyExit

    uint256 underlyingBalance = IERC20(underlying).balanceOf(address(this));
    if(amount > underlyingBalance){
      // While we have the check above, we still using SafeMath below
      // for the peace of mind (in case something gets changed in between)
      uint256 needToWithdraw = amount.sub(underlyingBalance);
      rewardPool.withdraw(Math.min(rewardPool.balanceOf(address(this)), needToWithdraw));
      WETH9 weth = WETH9(address(_weth));
      weth.deposit.value(address(this).balance)();
    }
    IERC20(underlying).safeTransfer(vault, amount);
  }

  /*
  *   Note that we currently do not have a mechanism here to include the
  *   amount of reward that is accrued.
  */
  function investedUnderlyingBalance() external view returns (uint256) {
    if (address(rewardPool) == address(0)) {
      return IERC20(underlying).balanceOf(address(this));
    }
    // Adding the amount locked in the reward pool and the amount that is somehow in this contract
    // both are in the units of "underlying"
    // The second part is needed because there is the emergency exit mechanism
    // which would break the assumption that all the funds are always inside of the reward pool
    return rewardPool.balanceOf(address(this)).add(IERC20(underlying).balanceOf(address(this)));
  }

  /*
  *   Governance or Controller can claim coins that are somehow transferred into the contract
  *   Note that they cannot come in take away coins that are used and defined in the strategy itself
  *   Those are protected by the "unsalvagableTokens". To check, see where those are being flagged.
  */
  function salvage(address recipient, address token, uint256 amount) external onlyControllerOrGovernance {
     // To make sure that governance cannot come in and take away the coins
    require(!unsalvagableTokens[token], "token is defined as not salvagable");
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
    rewardPool.getReward();
    _liquidateReward();
    investAllUnderlying();
  }

  function () external payable {} // this is needed for the WETH unwrapping
}
