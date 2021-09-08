pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/IRewardPool.sol";
import "../../base/interface/IVault.sol";
import "../../base/upgradability/BaseUpgradeableStrategyUL.sol";
import "../../base/interface/uniswap/IUniswapV2Pair.sol";
import "./interface/IStaking.sol";
import "./interface/IYieldFarming.sol";

contract UniverseStrategyBuyback is IStrategy, BaseUpgradeableStrategyUL {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // XYZ-ETH LP is on Sushiswap. Only used for depositing, liquidation goes through UL.
  address public constant sushiswapRouterV2 = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
  address public constant usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

  // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
  bytes32 internal constant _STAKING_POOL_SLOT = 0xf5fc8afd01a5fdb4cdac4f642858479fab8910ffb42050680a60bc68854d0678;
  bytes32 internal constant _IS_LP_ASSET_SLOT = 0xc2f3dabf55b1bdda20d5cf5fcba9ba765dfc7c9dbaf28674ce46d43d60d58768;
  bytes32 internal constant _DISTRIBUTION_POOL = 0xffff3ca4ef6be91c73d8650479019ed5238e272f1f8a0190b85eb7dae6fd4b6b;
  bytes32 internal constant _BUYBACK_RATIO = 0xec0174f2065dc3fa83d1e3b1944c6e3f68d25ad5cfc7af4559379936de9ba927;

  constructor() public BaseUpgradeableStrategyUL() {
    assert(_STAKING_POOL_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.stakingPool")) - 1));
    assert(_IS_LP_ASSET_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.isLpAsset")) - 1));
    assert(_DISTRIBUTION_POOL == bytes32(uint256(keccak256("eip1967.strategyStorage.distributionPool")) - 1));
    assert(_BUYBACK_RATIO == bytes32(uint256(keccak256("eip1967.strategyStorage.buybackRatio")) - 1));
  }

  function initializeBaseStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    address _rewardToken,
    address _stakingPool,
    bool _isLpAsset,
    address _distributionPool,
    uint256 _buybackRatio
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
    require(IRewardPool(_distributionPool).lpToken() == _vault, "Incompatible pool");
    require(_buybackRatio <= 10000, "Buyback ratio too high");

    setAddress(_STAKING_POOL_SLOT, _stakingPool);
    setBoolean(_IS_LP_ASSET_SLOT, _isLpAsset);

    setAddress(_DISTRIBUTION_POOL, _distributionPool);
    setUint256(_BUYBACK_RATIO, _buybackRatio);
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  function rewardPoolBalance() internal view returns (uint256 bal) {
      bal = IStaking(stakingPool()).balanceOf(address(this), underlying());
  }

  function exitRewardPool() internal {
      uint256 bal = rewardPoolBalance();
      if (bal != 0) {
          IStaking(stakingPool()).withdraw(underlying(), bal);
      }
  }

  function emergencyExitRewardPool() internal {
      uint256 bal = rewardPoolBalance();
      if (bal != 0) {
          IStaking(stakingPool()).emergencyWithdraw(underlying());
      }
  }

  function unsalvagableTokens(address token) public view returns (bool) {
    return (token == rewardToken() || token == underlying());
  }

  function enterRewardPool() internal {
    uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));
    IERC20(underlying()).safeApprove(stakingPool(), 0);
    IERC20(underlying()).safeApprove(stakingPool(), entireBalance);
    IStaking(stakingPool()).deposit(underlying(), entireBalance);
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

  // We assume that all the tradings can be done on Uniswap
  function liquidateReward() internal {
    uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    if (!sell() || rewardBalance < sellFloor()) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected(sell(), rewardBalance < sellFloor());
      return;
    }

    notifyProfitAndBuybackInRewardToken(
      rewardBalance,
      distributionPool(),
      buybackRatio()
    );
    uint256 remainingRewardBalance = IERC20(rewardToken()).balanceOf(address(this));

    if (remainingRewardBalance == 0) {
      return;
    }

    // allow UL to sell our reward
    IERC20(rewardToken()).safeApprove(universalLiquidator(), 0);
    IERC20(rewardToken()).safeApprove(universalLiquidator(), remainingRewardBalance);

    // we can accept 1 as minimum because this is called only by a trusted role
    uint256 amountOutMin = 1;

    if (isLpAsset()) {
      address lpComponentToken0 = IUniswapV2Pair(underlying()).token0();
      address lpComponentToken1 = IUniswapV2Pair(underlying()).token1();

      uint256 toToken0 = remainingRewardBalance.div(2);
      uint256 toToken1 = remainingRewardBalance.sub(toToken0);

      uint256 token0Amount;

      if (storedLiquidationDexes[rewardToken()][lpComponentToken0].length > 0) {
        // if we need to liquidate the token0
        ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
          toToken0,
          amountOutMin,
          address(this), // target
          storedLiquidationDexes[rewardToken()][lpComponentToken0],
          storedLiquidationPaths[rewardToken()][lpComponentToken0]
        );
        token0Amount = IERC20(lpComponentToken0).balanceOf(address(this));
      } else {
        // otherwise we assme token0 is the reward token itself
        token0Amount = toToken0;
      }

      uint256 token1Amount;

      if (storedLiquidationDexes[rewardToken()][lpComponentToken1].length > 0) {
        // sell reward token to token1
        ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
          toToken1,
          amountOutMin,
          address(this), // target
          storedLiquidationDexes[rewardToken()][lpComponentToken1],
          storedLiquidationPaths[rewardToken()][lpComponentToken1]
        );
        token1Amount = IERC20(lpComponentToken1).balanceOf(address(this));
      } else {
        token1Amount = toToken1;
      }

      // provide token1 and token2 to SUSHI
      IERC20(lpComponentToken0).safeApprove(sushiswapRouterV2, 0);
      IERC20(lpComponentToken0).safeApprove(sushiswapRouterV2, token0Amount);

      IERC20(lpComponentToken1).safeApprove(sushiswapRouterV2, 0);
      IERC20(lpComponentToken1).safeApprove(sushiswapRouterV2, token1Amount);

      // we provide liquidity to sushi
      uint256 liquidity;
      (,,liquidity) = IUniswapV2Router02(sushiswapRouterV2).addLiquidity(
        lpComponentToken0,
        lpComponentToken1,
        token0Amount,
        token1Amount,
        1,  // we are willing to take whatever the pair gives us
        1,  // we are willing to take whatever the pair gives us
        address(this),
        block.timestamp
      );
    } else {
      ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
        remainingRewardBalance,
        amountOutMin,
        address(this), // target
        storedLiquidationDexes[rewardToken()][underlying()],
        storedLiquidationPaths[rewardToken()][underlying()]
      );
    }
  }

  function claimReward() internal {
    IYieldFarming(rewardPool()).massHarvest();
  }

  /*
  *   Stakes everything the strategy holds into the reward pool
  */
  function investAllUnderlying() internal onlyNotPausedInvesting {
    // this check is needed, because most of the SNX reward pools will revert if
    // you try to stake(0).
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
    claimReward();
    liquidateReward();
    IERC20(underlying()).safeTransfer(vault(), IERC20(underlying()).balanceOf(address(this)));
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawToVault(uint256 amount) public restricted {
    // Typically there wouldn't be any amount here
    // however, it is possible because of the emergencyExit
    uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));

    if(amount > entireBalance){
      // While we have the check above, we still using SafeMath below
      // for the peace of mind (in case something gets changed in between)
      uint256 needToWithdraw = amount.sub(entireBalance);
      uint256 toWithdraw = Math.min(rewardPoolBalance(), needToWithdraw);
      IStaking(stakingPool()).withdraw(underlying(), toWithdraw);
    }
    IERC20(underlying()).safeTransfer(vault(), amount);
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

  function setStakingPool(address _value) public onlyGovernance {
    setAddress(_STAKING_POOL_SLOT, _value);
  }

  function stakingPool() public view returns (address) {
    return getAddress(_STAKING_POOL_SLOT);
  }

  function setBuybackRatio(uint256 _newRatio) public onlyGovernance {
    setUint256(_BUYBACK_RATIO, _newRatio);
  }

  function isLpAsset() public view returns (bool) {
    return getBoolean(_IS_LP_ASSET_SLOT);
  }

  function distributionPool() public view returns (address) {
    return getAddress(_DISTRIBUTION_POOL);
  }

  function buybackRatio() public view returns (uint256) {
    return getUint256(_BUYBACK_RATIO);
  }

  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
  }
}
