pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../StrategyBase.sol";
import "../interface/uniswap/IUniswapV2Router02.sol";
import "../interface/IVault.sol";
import "../interface/IRewardDistributionSwitcher.sol";
import "../interface/uniswap/IUniswapV2Pair.sol";
import "../interface/INoMintRewardPool.sol";
import "./interfaces/SNXRewardInterface.sol";

/*
*   This is a general strategy for yields that are based on the synthetix reward contract
*   for example, yam, spaghetti, ham, shrimp.
*
*   One strategy is deployed for one underlying asset, but the design of the contract
*   should allow it to switch between different reward contracts.
*
*   It is important to note that not all SNX reward contracts that are accessible via the same interface are
*   suitable for this Strategy. One concrete example is CREAM.finance, as it implements a "Lock" feature and
*   would not allow the user to withdraw within some timeframe after the user have deposited.
*   This would be problematic to user as our "invest" function in the vault could be invoked by anyone anytime
*   and thus locking/reverting on subsequent withdrawals. Another variation is the YFI Governance: it can
*   activate a vote lock to stop withdrawal.
*
*   Ref:
*   1. CREAM https://etherscan.io/address/0xc29e89845fa794aa0a0b8823de23b760c3d766f5#code
*   2. YAM https://etherscan.io/address/0x8538E5910c6F80419CD3170c26073Ff238048c9E#code
*   3. SHRIMP https://etherscan.io/address/0x9f83883FD3cadB7d2A83a1De51F9Bf483438122e#code
*   4. BASED https://etherscan.io/address/0x5BB622ba7b2F09BF23F1a9b509cd210A818c53d7#code
*   5. YFII https://etherscan.io/address/0xb81D3cB2708530ea990a287142b82D058725C092#code
*   6. YFIGovernance https://etherscan.io/address/0xBa37B002AbaFDd8E89a1995dA52740bbC013D992#code
*
*
*
*   Respecting the current system design of choosing the best strategy under the vault, and also rewarding/funding
*   the public key that invokes the switch of strategies, this smart contract should be deployed twice and linked
*   to the same vault. When the governance want to rotate the crop, they would set the reward source on the strategy
*   that is not active, then set that apy higher and this one lower.
*
*   Consequently, in the smart contract we restrict that we can only set a new reward source when it is not active.
*
*/

contract SNXReward2FarmStrategyV2 is StrategyBase {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public farm;
  address public weth;
  address public distributionPool;
  address public distributionSwitcher;
  address public rewardToken;
  address public sushiswapRouterV2;

  bool public pausedInvesting = false; // When this flag is true, the strategy will not be able to invest. But users should be able to withdraw.

  SNXRewardInterface public rewardPool;

  // a flag for disabling selling for simplified emergency exit
  bool public sell = true;
  uint256 public sellFloor = 1e6;

  // if set to true, it liquidates the reward token to weth in sushi.
  // afterwards, it liquidates from weth to farm in uniswap.
  bool public liquidateRewardToWethInSushi;  
  mapping (address => address[]) public liquidationRoutes;

  // if the flag is set, then it would read the previous reward distribution from the pool
  // otherwise, it would read from `setRewardDistributionTo` and ask the distributionSwitcher to set to it.
  bool public autoRevertRewardDistribution;
  address public defaultRewardDistribution;

  event ProfitsNotCollected();

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
    address _rewardPool,
    address _rewardToken,
    address _uniswapRouterV2,
    address _sushiswapRouterV2,
    address _farm,
    address _weth,
    address _distributionPool,
    address _distributionSwitcher
  )
  StrategyBase(_storage, _underlying, _vault, _farm, _uniswapRouterV2)
  public {
    require(_vault == INoMintRewardPool(_distributionPool).lpToken(), "distribution pool's lp must be the vault");
    
    farm = _farm;
    weth = _weth;
    distributionPool = _distributionPool;
    rewardToken = _rewardToken;
    distributionSwitcher = _distributionSwitcher;
    rewardPool = SNXRewardInterface(_rewardPool);
    sushiswapRouterV2 = _sushiswapRouterV2;
    autoRevertRewardDistribution = true;
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  /*
  *   In case there are some issues discovered about the pool or underlying asset
  *   Governance can exit the pool properly
  *   The function is only used for emergency to exit the pool
  */
  function emergencyExit() public onlyGovernance {
    rewardPool.exit();
    pausedInvesting = true;
  }

  /*
  *   Resumes the ability to invest into the underlying reward pools
  */

  function continueInvesting() public onlyGovernance {
    pausedInvesting = false;
  }


  function setLiquidationPaths(address tokenToLiquidate, address [] memory _uniswapRouteFarm) public onlyGovernance {
    liquidationRoutes[tokenToLiquidate] = _uniswapRouteFarm;
  }

  // We assume that all the tradings can be done on Uniswap
  function _liquidateReward() internal {
    address tokenToLiquidate = rewardToken;
    uint256 rewardBalance = IERC20(rewardToken).balanceOf(address(this));
    if (!sell || rewardBalance < sellFloor) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected();
      return;
    }

    uint256 amountOutMin = 1;
    if(liquidateRewardToWethInSushi) {
      // allow Uniswap to sell our reward

      IERC20(rewardToken).safeApprove(sushiswapRouterV2, 0);
      IERC20(rewardToken).safeApprove(sushiswapRouterV2, rewardBalance);

      // sell reward token to FARM
      // we can accept 1 as minimum because this is called only by a trusted role

      uint256 wethAmount;

      require(liquidationRoutes[rewardToken].length > 1, "The liquidation path for [Reward -> WETH] must be set.");

      IUniswapV2Router02(sushiswapRouterV2).swapExactTokensForTokens(
        rewardBalance,
        amountOutMin,
        liquidationRoutes[rewardToken],
        address(this),
        block.timestamp
      );

      wethAmount = IERC20(weth).balanceOf(address(this));

      tokenToLiquidate = weth;
      rewardBalance = wethAmount;
    }

    IERC20(tokenToLiquidate).safeApprove(uniswapRouterV2, 0);
    IERC20(tokenToLiquidate).safeApprove(uniswapRouterV2, rewardBalance);

    uint256 farmAmount;
    if (liquidationRoutes[tokenToLiquidate].length > 1) {
      
      IUniswapV2Router02(uniswapRouterV2).swapExactTokensForTokens(
        rewardBalance,
        amountOutMin,
        liquidationRoutes[tokenToLiquidate],
        address(this),
        block.timestamp
      );

      farmAmount = IERC20(farm).balanceOf(address(this));
    } else {
      revert("The liquidation path to FARM must be set.");
    }

    // Use farm as protif sharing base, sending it 
    notifyProfitInRewardToken(farmAmount);

    // The remaining farms should be distributed to the distribution pool
    farmAmount = IERC20(farm).balanceOf(address(this));

    // Switch reward distribution temporarily, notify reward, switch it back
    address prevRewardDistribution;
    if(autoRevertRewardDistribution) {      
      prevRewardDistribution = INoMintRewardPool(distributionPool).rewardDistribution();
    } else {
      prevRewardDistribution = defaultRewardDistribution;
    }
    IRewardDistributionSwitcher(distributionSwitcher).setPoolRewardDistribution(distributionPool, address(this));
    // transfer and notify with the remaining farm amount
    IERC20(farm).safeTransfer(distributionPool, farmAmount);
    INoMintRewardPool(distributionPool).notifyRewardAmount(farmAmount);
    IRewardDistributionSwitcher(distributionSwitcher).setPoolRewardDistribution(distributionPool, prevRewardDistribution);
  }

  /*
  *   Stakes everything the strategy holds into the reward pool
  */
  function investAllUnderlying() internal onlyNotPausedInvesting {
    // this check is needed, because most of the SNX reward pools will revert if
    // you try to stake(0).
    if(IERC20(underlying).balanceOf(address(this)) > 0) {
      IERC20(underlying).approve(address(rewardPool), IERC20(underlying).balanceOf(address(this)));
      rewardPool.stake(IERC20(underlying).balanceOf(address(this)));
    }
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawAllToVault() public restricted {
    if (address(rewardPool) != address(0)) {
      if (rewardPool.balanceOf(address(this)) > 0) {
        rewardPool.exit();
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
  function withdrawToVault(uint256 amount) public restricted {
    // Typically there wouldn't be any amount here
    // however, it is possible because of the emergencyExit
    if(amount > IERC20(underlying).balanceOf(address(this))){
      // While we have the check above, we still using SafeMath below
      // for the peace of mind (in case something gets changed in between)
      uint256 needToWithdraw = amount.sub(IERC20(underlying).balanceOf(address(this)));
      rewardPool.withdraw(Math.min(rewardPool.balanceOf(address(this)), needToWithdraw));
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

  /**
  * Can completely disable claiming UNI rewards and selling. Good for emergency withdraw in the
  * simplest possible way.
  */
  function setSell(bool s) public onlyGovernance {
    sell = s;
  }

  /**
  * Sets the minimum amount of CRV needed to trigger a sale.
  */
  function setSellFloor(uint256 floor) public onlyGovernance {
    sellFloor = floor;
  }

  function overrideRewardDistributionTo(bool _autoRevertRewardDistribution, address _defaultRewardDistribution) public onlyGovernance {
    autoRevertRewardDistribution = _autoRevertRewardDistribution;
    defaultRewardDistribution = _defaultRewardDistribution;
  }

  function setLiquidateRewardToWethInSushi(bool _flag) public onlyGovernance {
    liquidateRewardToWethInSushi = _flag;
  }  
}
