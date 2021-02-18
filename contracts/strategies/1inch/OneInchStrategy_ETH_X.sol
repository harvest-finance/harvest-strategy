pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interface/IMooniswap.sol";
import "./interface/IFarmingRewards.sol";

import "../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "../../base/interface/weth/Weth9.sol";

import "../../base/StrategyBase.sol";

/**
* This strategy is for ETH / X 1inch LP tokens
* ETH must be token0, and the other token is denoted X
*/
contract OneInchStrategy_ETH_X is StrategyBase {

  // 1inch / ETH reward pool: 0x9070832CF729A5150BB26825c2927e7D343EabD9

  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  event Liquidating(address token, uint256 amount);
  event ProfitsNotCollected(address token);

  address public pool;
  address public oneInch = address(0x111111111117dC0aa78b770fA6A738034120C302);

  address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public uni = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  address public oneInchCaller = address(0xe069CB01D06bA617bCDf789bf2ff0D5E5ca20C71);

  uint256 maxUint = uint256(~0);
  address public oneInchEthLP;
  address[] public uniswap_WETH2Token1;

  // token0 is ETH
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
    address _pool,
    address _oneInchEthLP
  )
  StrategyBase(_storage, _underlying, _vault, weth, address(0)) public {
    require(IVault(_vault).underlying() == _underlying, "vault does not support the required LP token");
    token1 = IMooniswap(_underlying).token1();
    pool = _pool;
    require(token1 != address(0), "token1 must be non-zero");
    require(IMooniswap(_underlying).token0() == address(0), "token0 must be 0x0 (Ether)");
    oneInchEthLP = _oneInchEthLP;
    uniswap_WETH2Token1 = [weth, token1];

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
    IFarmingRewards(pool).withdraw(
      Math.min(IFarmingRewards(pool).balanceOf(address(this)), amount)
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
      IFarmingRewards(pool).stake(underlyingBalance);
    }
  }

  function() external payable {}

  /**
  * Claims the 1Inch crop, converts it accordingly
  */

  function claimAndLiquidate() internal {
    if (!sell) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected(oneInch);
      return;
    }
    IFarmingRewards(pool).getReward();
    uint256 oneInchBalance = IERC20(oneInch).balanceOf(address(this));
    if (oneInchBalance < sellFloorOneInch) {
      emit ProfitsNotCollected(oneInch);
      return;
    }

    // converting the reward token (1inch) into Ether
    uint256 amountOutMin = 1;

    IERC20(oneInch).safeApprove(oneInchEthLP, 0);
    IERC20(oneInch).safeApprove(oneInchEthLP, oneInchBalance);

    IMooniswap(oneInchEthLP).swap(oneInch, address(0), oneInchBalance, amountOutMin, address(0));

    // convert the received Ether into wrapped Ether
    WETH9(weth).deposit.value(address(this).balance)();
    uint256 wethBalance = IERC20(weth).balanceOf(address(this));
    if( wethBalance == 0 ) {
      emit ProfitsNotCollected(weth);
      return;
    }

    // share 30% of the wrapped Ether as a profit sharing reward
    notifyProfitInRewardToken(wethBalance);

    uint256 remainingWethBalance = IERC20(weth).balanceOf(address(this));

    IERC20(weth).safeApprove(uni, 0);
    IERC20(weth).safeApprove(uni, remainingWethBalance.div(2));

    // with the remaining, half would be converted into the second token
    IUniswapV2Router02(uni).swapExactTokensForTokens(
      remainingWethBalance.div(2),
      amountOutMin,
      uniswap_WETH2Token1,
      address(this),
      block.timestamp
    );
    uint256 token1Amount = IERC20(token1).balanceOf(address(this));

    // and the other half - unwrapped
    remainingWethBalance = IERC20(weth).balanceOf(address(this));
    IERC20(weth).safeApprove(weth, 0);
    IERC20(weth).safeApprove(weth, remainingWethBalance);
    WETH9(weth).withdraw(remainingWethBalance);
    uint256 remainingEthBalance = address(this).balance;

    IERC20(token1).safeApprove(underlying, 0);
    IERC20(token1).safeApprove(underlying, token1Amount);

    // adding liquidity: ETH + token1
    IMooniswap(underlying).deposit.value(remainingEthBalance)(
      [remainingEthBalance, token1Amount],
      [remainingEthBalance.mul(slippageNumerator).div(slippageDenominator),
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
    return IFarmingRewards(pool).balanceOf(address(this)).add(
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
