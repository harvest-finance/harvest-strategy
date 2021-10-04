pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interface/IMooniswap.sol";
import "../interface/IFarmingRewardsV2.sol";

import "../../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../../base/interface/IStrategy.sol";
import "../../../base/interface/IVault.sol";
import "../../../base/interface/weth/Weth9.sol";

import "../../../base/StrategyBase.sol";

/**
* This strategy is for DAI / X 1inch LP tokens
* DAI must be token0, and the other token is denoted X
*/
contract OneInchStrategy_DAI_X is IStrategy, BaseUpgradeableStrategyUL {

  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  address public dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  uint256 maxUint = uint256(~0);
  uint256 slippageNumerator = 9;
  uint256 slippageDenominator = 10;

  // depositToken0 is DAI
  // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
  bytes32 internal constant _DEPOSIT_TOKEN_SLOT = 0x219270253dbc530471c88a9e7c321b36afda219583431e7b6c386d2d46e70c86;

  address[] public rewardTokens;

  constructor() public BaseUpgradeableStrategyUL() {
    assert(_DEPOSIT_TOKEN_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositToken")) - 1));
  }

  function initializeBaseStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    uint256 _profitSharingNumerator
  ) public initializer {

    BaseUpgradeableStrategyUL.initialize(
      _storage,
      _underlying,
      _vault,
      _rewardPool,
      weth,
      _profitSharingNumerator,  // profit sharing numerator
      1000, // profit sharing denominator
      true, // sell
      0, // sell floor
      12 hours, // implementation change delay
      address(0x7882172921E99d590E097cD600554339fBDBc480) // UL Registry
    );

    require(IVault(_vault).underlying() == _underlying, "vault does not support the required LP token");
    _setDepositToken(IMooniswap(_underlying).token1());
    require(depositToken() != address(0), "token1 must be non-zero");
    require(IMooniswap(_underlying).token0() == dai, "token0 must be dai");

    rewardTokens = new address[](0);
  }

  function depositArbCheck() public view returns(bool) {
    return true;
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

  function emergencyExitRewardPool() internal {
    withdrawUnderlyingFromPool(maxUint);
    uint256 balance = IERC20(underlying()).balanceOf(address(this));
    IERC20(underlying()).safeTransfer(vault(), balance);
  }

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

  /**
  * Withdraws underlying from the investment rewardPool() that mints crops.
  */
  function withdrawUnderlyingFromPool(uint256 amount) internal {
    IFarmingRewardsV2(rewardPool()).withdraw(
      Math.min(IFarmingRewardsV2(rewardPool()).balanceOf(address(this)), amount)
    );
  }

  /**
  * Withdraws the underlying tokens to the rewardPool() in the specified amount.
  */
  function withdrawToVault(uint256 amountUnderlying) external restricted {
    withdrawUnderlyingFromPool(amountUnderlying);
    require(IERC20(underlying()).balanceOf(address(this)) >= amountUnderlying, "insufficient balance for the withdrawal");
    IERC20(underlying()).safeTransfer(vault, amountUnderlying);
  }

  /**
  * Withdraws all the underlying tokens to the rewardPool().
  */
  function withdrawAllToVault() external restricted {
    claimAndLiquidate();
    withdrawUnderlyingFromPool(maxUint);
    uint256 balance = IERC20(underlying()).balanceOf(address(this));
    IERC20(underlying()).safeTransfer(vault(), balance);
  }

  /**
  * Invests all the underlying into the rewardPool() that mints crops (1inch)
  */
  function investAllUnderlying() public restricted {
    uint256 underlyingBalance = IERC20(underlying()).balanceOf(address(this));
    if (underlyingBalance > 0) {
      IERC20(underlying()).safeApprove(rewardPool(), 0);
      IERC20(underlying()).safeApprove(rewardPool(), underlyingBalance);
      IFarmingRewardsV2(rewardPool()).stake(underlyingBalance);
    }
  }

  function() external payable {}

  /**
  * liquidates rewards via defined dexes such as uni / sushi and redeposits
  * and converts accordingly for reinvesting underlying
  */
  function liquidateReward() internal {
    if (!sell()) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected(sell(), false);
      return;
    }

    // multiple reward tokens are supported -> liquidate all of them into common rewardToken (weth)
    for(uint256 i = 0; i < rewardTokens.length; i++){
      address rewardToken = rewardTokens[i];
      uint256 rewardBalance = IERC20(rewardToken).balanceOf(address(this));
      if (rewardBalance == 0 || storedLiquidationDexes[rewardToken][weth].length < 1) {
        continue;
      }

      IERC20(rewardToken).safeApprove(universalLiquidator(), 0);
      IERC20(rewardToken).safeApprove(universalLiquidator(), rewardBalance);
      // we can accept 1 as the minimum because this will be called only by a trusted worker
      ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
        rewardBalance,
        1,
        address(this), // target
        storedLiquidationDexes[rewardToken][weth],
        storedLiquidationPaths[rewardToken][weth]
      );
    }

    uint256 rewardBalance = IERC20(weth).balanceOf(address(this));

    // share 30% of the wrapped Ether as a profit sharing reward
    notifyProfitInRewardToken(rewardBalance);
    uint256 remainingRewardBalance = IERC20(rewardToken()).balanceOf(address(this));

    if (remainingRewardBalance == 0) {
      return;
    }

    // convert half of the remaining rewardBalance back to the main deposit token DAI
    IERC20(rewardToken()).safeApprove(universalLiquidator(), 0);
    IERC20(rewardToken()).safeApprove(universalLiquidator(), remainingRewardBalance.div(2));
    // we can accept 1 as minimum because this is called only by a trusted role
    ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
      remainingRewardBalance.div(2),
      1,
      address(this), // target
      storedLiquidationDexes[weth][dai],
      storedLiquidationPaths[weth][dai]
    );

    // the remaining half is converted into the second token
    remainingRewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    IERC20(rewardToken()).safeApprove(universalLiquidator(), 0);
    IERC20(rewardToken()).safeApprove(universalLiquidator(), remainingRewardBalance);
    // we can accept 1 as minimum because this is called only by a trusted role
    ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
      remainingRewardBalance,
      1,
      address(this), // target
      storedLiquidationDexes[weth][depositToken()],
      storedLiquidationPaths[weth][depositToken()]
    );

    depositMooniSwap();
  }

  function depositMooniSwap() internal {
    int256 token1Amount = IERC20(depositToken()).balanceOf(address(this));
    uint256 daiAmount = IERC20(dai).balanceOf(address(this));
    if (!(daiAmount > 0 && token1Amount > 0)) {
      return;
    }

    IERC20(depositToken()).safeApprove(underlying(), 0);
    IERC20(depositToken()).safeApprove(underlying(), token1Amount);

    IERC20(oneInch).safeApprove(underlying(), 0);
    IERC20(oneInch).safeApprove(underlying(), oneInchAmount);

    // adding liquidity: DAI + depositToken()
    IMooniswap(underlying()).deposit(
        [daiAmount, token1Amount],
        [
          daiAmount.mul(slippageNumerator).div(slippageDenominator),
          token1Amount.mul(slippageNumerator).div(slippageDenominator)
        ]
    );
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
    IFarmingRewardsV2(rewardPool()).getAllRewards();
    liquidateReward();
    investAllUnderlying();
  }

  /**
  * Investing all underlying.
  */
  function investedUnderlyingBalance() public view returns (uint256) {
    return IFarmingRewardsV2(rewardPool()).balanceOf(address(this)).add(
      IERC20(underlying()).balanceOf(address(this))
    );
  }

  function unsalvagableTokens(address token) public view returns (bool) {
    return (token == rewardToken() || token == underlying());
  }

  /**
  * Can completely disable claiming UNI rewards and selling. Good for emergency withdraw in the
  * simplest possible way.
  */
  function setSell(bool s) public onlyGovernance {
    _setSell(s);
  }

  /**
  * Sets the minimum amount of rewardToken() needed to trigger a sale.
  */
  function setSellFloor(uint256 floor) public onlyGovernance {
    _setSellFloor(floor);
  }

  function _setDepositToken(address _address) internal {
    setAddress(_DEPOSIT_TOKEN_SLOT, _address);
  }

  function depositToken() public view returns (address) {
    return getAddress(_DEPOSIT_TOKEN_SLOT);
  }

  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
  }
}