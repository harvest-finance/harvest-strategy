pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interface/IMooniswap.sol";
import "./interface/IFarmingRewardsV2.sol";

import "../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "../../base/interface/weth/Weth9.sol";

import "../../base/StrategyBase.sol";

/**
* This strategy is for 1INCH / X 1inch LP tokens
* 1INCH must be token0, and the other token is denoted X
*/
contract OneInchStrategy_1INCH_X is StrategyBase {

  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  event Liquidating(address token, uint256 amount);
  event ProfitsNotCollected(address token);

  address public pool;
  address public oneInch = address(0x111111111117dC0aa78b770fA6A738034120C302);

  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public uni = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  uint256 maxUint = uint256(~0);
  address public oneInchEthLP;

  // token0 is ONEINCH
  address public token1;

  uint256 slippageNumerator = 9;
  uint256 slippageDenominator = 10;

  // a flag for disabling selling for simplified emergency exit
  bool public sell = true;
  // minimum 1inch amount to be liquidation
  uint256 public sellFloorOneInch = 1e17;

  constructor(
    address _storage,
    address _vault,
    address _underlying,
    address _pool
  )
  StrategyBase(_storage, _underlying, _vault, oneInch, address(0)) public {
    require(IVault(_vault).underlying() == _underlying, "vault does not support the required LP token");
    token1 = IMooniswap(_underlying).token1();
    pool = _pool;
    require(token1 != address(0), "token1 must be non-zero");
    require(IMooniswap(_underlying).token0() == oneInch, "token0 must be 0x0 (Ether)");

    // making 1inch reward token salvagable to be able to
    // liquidate externally
    unsalvagableTokens[oneInch] = false;
    unsalvagableTokens[token1] = true;
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  /**
  * Salvages a token. We should not be able to salvage underlying.
  */
  function salvage(address recipient, address token, uint256 amount) public onlyGovernance {
    // To make sure that governance cannot come in and take away the coins
    require(!unsalvagableTokens[token], "token is defined as not salvageable");
    IERC20(token).safeTransfer(recipient, amount);
  }

  /**
  * Withdraws underlying from the investment pool that mints crops.
  */
  function withdrawUnderlyingFromPool(uint256 amount) internal {
    IFarmingRewardsV2(pool).withdraw(
      Math.min(IFarmingRewardsV2(pool).balanceOf(address(this)), amount)
    );
  }

  /**
  * Withdraws the underlying tokens to the pool in the specified amount.
  */
  function withdrawToVault(uint256 amountUnderlying) external restricted {
    withdrawUnderlyingFromPool(amountUnderlying);
    require(IERC20(underlying).balanceOf(address(this)) >= amountUnderlying, "insufficient balance for the withdrawal");
    IERC20(underlying).safeTransfer(vault, amountUnderlying);
  }

  /**
  * Withdraws all the underlying tokens to the pool.
  */
  function withdrawAllToVault() external restricted {
    claimAndLiquidate();
    withdrawUnderlyingFromPool(maxUint);
    uint256 balance = IERC20(underlying).balanceOf(address(this));
    IERC20(underlying).safeTransfer(vault, balance);
  }

  /**
  * Invests all the underlying into the pool that mints crops (1inch)
  */
  function investAllUnderlying() public restricted {
    uint256 underlyingBalance = IERC20(underlying).balanceOf(address(this));
    if (underlyingBalance > 0) {
      IERC20(underlying).safeApprove(pool, 0);
      IERC20(underlying).safeApprove(pool, underlyingBalance);
      IFarmingRewardsV2(pool).stake(underlyingBalance);
    }
  }

  /**
  * Claims the 1Inch crop, converts it accordingly
  */

  function claimAndLiquidate() internal {
    if (!sell) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected(oneInch);
      return;
    }
    IFarmingRewardsV2(pool).getAllRewards();
    uint256 oneInchBalance = IERC20(oneInch).balanceOf(address(this));
    if (oneInchBalance < sellFloorOneInch) {
      emit ProfitsNotCollected(oneInch);
      return;
    }

    // share 30% of the 1INCH as a profit sharing reward
    notifyProfitInRewardToken(oneInchBalance);

    uint256 remainingBalance = IERC20(oneInch).balanceOf(address(this));

    IERC20(oneInch).safeApprove(underlying, 0);
    IERC20(oneInch).safeApprove(underlying, remainingBalance.div(2));

    // with the remaining, half would be converted into the second token
    uint256 amountOutMin = 1;
    IMooniswap(underlying).swap(oneInch, token1, remainingBalance.div(2), amountOutMin, address(0));

    uint256 oneInchAmount = IERC20(oneInch).balanceOf(address(this));
    uint256 token1Amount = IERC20(token1).balanceOf(address(this));

    IERC20(oneInch).safeApprove(underlying, 0);
    IERC20(oneInch).safeApprove(underlying, oneInchAmount);
    IERC20(token1).safeApprove(underlying, 0);
    IERC20(token1).safeApprove(underlying, token1Amount);

    // adding liquidity: ETH + token1
    IMooniswap(underlying).deposit(
      [oneInchAmount, token1Amount],
      [oneInchAmount.mul(slippageNumerator).div(slippageDenominator),
        token1Amount.mul(slippageNumerator).div(slippageDenominator)
      ]
    );
  }

  /**
  * Claims and liquidates 1inch into underlying, and then invests all underlying.
  */
  function doHardWork() public restricted {
    claimAndLiquidate();
    investAllUnderlying();
  }

  /**
  * Investing all underlying.
  */
  function investedUnderlyingBalance() public view returns (uint256) {
    return IFarmingRewardsV2(pool).balanceOf(address(this)).add(
      IERC20(underlying).balanceOf(address(this))
    );
  }

  /**
  * Can completely disable claiming 1inch rewards and selling. Good for emergency withdraw in the
  * simplest possible way.
  */
  function setSell(bool s) public onlyGovernance {
    sell = s;
  }

  /**
  * Sets the minimum amount of 1inch needed to trigger a sale.
  */
  function setSellFloorAndSlippages(uint256 _sellFloorOneInch, uint256 _slippageNumerator, uint256 _slippageDenominator) public onlyGovernance {
    sellFloorOneInch = _sellFloorOneInch;
    slippageNumerator = _slippageNumerator;
    slippageDenominator = _slippageDenominator;
  }
}
