// SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "../../base/upgradability/BaseUpgradeableStrategyUL.sol";
import "./interface/IGauge.sol";
import "./interface/ISolidlyRouter.sol";
import "./interface/ISolidlyPair.sol";

contract SolidlyStrategy is IStrategy, BaseUpgradeableStrategyUL {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant solidlyRouter = address(0x77784f96C936042A3ADB1dD29C91a55EB2A4219f);
  address public constant solid = address(0x777172D858dC1599914a1C4c6c9fC48c99a60990);

  address[] public rewardTokens;

  constructor() public BaseUpgradeableStrategyUL() {}

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
      300, // profit sharing numerator
      1000, // profit sharing denominator
      true, // sell
      1e18, // sell floor
      12 hours, // implementation change delay
      address(0x7882172921E99d590E097cD600554339fBDBc480) //UL Registry
    );
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  function rewardPoolBalance() internal view returns (uint256 balance) {
    balance = IGauge(rewardPool()).balanceOf(address(this));
  }

  function emergencyExitRewardPool() internal {
    uint256 stakedBalance = rewardPoolBalance();
    if (stakedBalance != 0) {
        withdrawUnderlyingFromPool(stakedBalance);
    }
  }

  function withdrawUnderlyingFromPool(uint256 amount) internal {
    address rewardPool_ = rewardPool();
    IGauge(rewardPool_).withdraw(
      Math.min(IGauge(rewardPool_).balanceOf(address(this)), amount)
    );
  }

  function enterRewardPool() internal {
    address underlying_ = underlying();
    address rewardPool_ = rewardPool();
    uint256 entireBalance = IERC20(underlying_).balanceOf(address(this));
    IERC20(underlying_).safeApprove(rewardPool_, 0);
    IERC20(underlying_).safeApprove(rewardPool_, entireBalance);
    IGauge(rewardPool_).deposit(entireBalance, 0);
  }

  function investAllUnderlying() internal onlyNotPausedInvesting {
    // this check is needed, because most of the SNX reward pools will revert if
    // you try to stake(0).
    if(IERC20(underlying()).balanceOf(address(this)) > 0) {
      enterRewardPool();
    }
  }

  function swapSolidToWeth(uint256 amount) internal {
    IERC20(solid).safeApprove(solidlyRouter, 0);
    IERC20(solid).safeApprove(solidlyRouter, amount);

    ISolidlyRouter.Route[] memory routes = new ISolidlyRouter.Route[](1);
    routes[0] = ISolidlyRouter.Route({
      from: solid,
      to: weth,
      stable: false
    });
    ISolidlyRouter(solidlyRouter).swapExactTokensForTokens(
      amount,
      1,
      routes,
      address(this),
      block.timestamp
    );
  }

  function swapWethToSolid(uint256 amount) internal {
    IERC20(weth).safeApprove(solidlyRouter, 0);
    IERC20(weth).safeApprove(solidlyRouter, amount);

    ISolidlyRouter.Route[] memory routes;
    routes[0] = ISolidlyRouter.Route({
      from: weth,
      to: solid,
      stable: false
    });

    ISolidlyRouter(solidlyRouter).swapExactTokensForTokens(
      amount,
      1,
      routes,
      address(this),
      block.timestamp
    );
  }

  function unsalvagableTokens(address token) public view returns (bool) {
    return (token == rewardToken() || token == underlying());
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

  function addRewardToken(address _token) public onlyGovernance {
    rewardTokens.push(_token);
  }

  /*
  *   Assume the rewardToken is weth here
  */
  function liquidateReward() internal {
    if (!sell()) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected(sell(), false);
      return;
    }

    {
      for(uint256 i = 0; i < rewardTokens.length; i++) {
        address token = rewardTokens[i];
        uint256 rewardBalance = IERC20(token).balanceOf(address(this));

        if (rewardBalance == 0) {
          continue;
        }
        
        if(token == solid) {
          swapSolidToWeth(rewardBalance);
        } else if(storedLiquidationDexes[token][weth].length > 0) {
          ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
            rewardBalance,
            1,
            address(this), // target
            storedLiquidationDexes[token][weth],
            storedLiquidationPaths[token][weth]
          );
        }
      }
    }

    {
      uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
      notifyProfitInRewardToken(rewardBalance);
    }

    uint256 remainingRewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    if (remainingRewardBalance == 0) {
      return;
    }

    address _underlying = underlying();
    address token0 = ISolidlyPair(_underlying).token0();
    address token1 = ISolidlyPair(_underlying).token1();

    uint256 toToken0 = remainingRewardBalance.div(2);
    uint256 toToken1 = remainingRewardBalance.sub(toToken0);

    IERC20(rewardToken()).safeApprove(universalLiquidator(), 0);
    IERC20(rewardToken()).safeApprove(universalLiquidator(), remainingRewardBalance);

    uint256 token0Amount;
    if (token0 == solid) {
      swapWethToSolid(toToken0);
      token0Amount = IERC20(token0).balanceOf(address(this));
    } else if (storedLiquidationDexes[rewardToken()][token0].length > 0) {
      ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
        toToken0,
        1,
        address(this), // target
        storedLiquidationDexes[rewardToken()][token0],
        storedLiquidationPaths[rewardToken()][token0]
      );
      token0Amount = IERC20(token0).balanceOf(address(this));
    } else {
      // otherwise we assme token0 is weth itself
      token0Amount = toToken0;
    }

    uint256 token1Amount;
    if (token1 == solid) {
      swapWethToSolid(toToken1);
      token1Amount = IERC20(token1).balanceOf(address(this));
    } else if (storedLiquidationDexes[rewardToken()][token1].length > 0) {
      ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
        toToken1,
        1,
        address(this), // target
        storedLiquidationDexes[rewardToken()][token1],
        storedLiquidationPaths[rewardToken()][token1]
      );
      token1Amount = IERC20(token1).balanceOf(address(this));
    } else {
      // otherwise we assme token1 is weth itself
      token1Amount = toToken1;
    }

    // provide token1 and token2 to Solidly
    IERC20(token0).safeApprove(solidlyRouter, 0);
    IERC20(token0).safeApprove(solidlyRouter, token0Amount);

    IERC20(token1).safeApprove(solidlyRouter, 0);
    IERC20(token1).safeApprove(solidlyRouter, token1Amount);

    ISolidlyRouter(solidlyRouter).addLiquidity(
      token0,
      token1,
      ISolidlyPair(_underlying).stable(), 
      token0Amount,
      token1Amount,
      1,
      1,
      address(this),
      block.timestamp
    );
  }

  function claimReward() internal {
    IGauge(rewardPool()).getReward(address(this), rewardTokens);
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawAllToVault() public restricted {
    withdrawUnderlyingFromPool(rewardPoolBalance());
    liquidateReward();
    address underlying_ = underlying();
    IERC20(underlying_).safeTransfer(vault(), IERC20(underlying_).balanceOf(address(this)));
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawToVault(uint256 amount) public restricted {
    // Typically there wouldn't be any amount here
    // however, it is possible because of the emergencyExit
    address underlying_ = underlying();
    uint256 entireBalance = IERC20(underlying_).balanceOf(address(this));

    if(amount > entireBalance){
      // While we have the check above, we still using SafeMath below
      // for the peace of mind (in case something gets changed in between)
      uint256 needToWithdraw = amount.sub(entireBalance);
      uint256 toWithdraw = Math.min(rewardPoolBalance(), needToWithdraw);
      withdrawUnderlyingFromPool(toWithdraw);
    }
    IERC20(underlying_).safeTransfer(vault(), amount);
  }

  /*
  *   Note that we currently do not have a mechanism here to include the
  *   amount of reward that is accrued.
  */
  function investedUnderlyingBalance() external view returns (uint256) {
    if (rewardPool() == address(0)) {
      return IERC20(underlying()).balanceOf(address(this));
    }
    // Adding the amount locked in the reward pool and the amount that is somehow in this contract
    // both are in the units of "underlying"
    // The second part is needed because there is the emergency exit mechanism
    // which would break the assumption that all the funds are always inside of the reward pool
    return rewardPoolBalance().add(IERC20(underlying()).balanceOf(address(this)));
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
  *
  *   Note that although `onlyNotPausedInvesting` is not added here,
  *   calling `investAllUnderlying()` affectively blocks the usage of `doHardWork`
  *   when the investing is being paused by governance.
  */
  function doHardWork() external onlyNotPausedInvesting restricted {
    claimReward();
    liquidateReward();
    investAllUnderlying();
  }

  function setSell(bool s) public onlyGovernance {
    _setSell(s);
  }

  function setSellFloor(uint256 floor) public onlyGovernance {
    _setSellFloor(floor);
  }

  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
  }
}
