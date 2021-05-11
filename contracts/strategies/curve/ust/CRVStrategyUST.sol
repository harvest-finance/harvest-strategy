pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../base/interface/curve/Gauge.sol";
import "../../../base/interface/curve/ICurveBUSDDeposit.sol";
import "../../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../../base/interface/IStrategy.sol";
import "../../../base/interface/IVault.sol";

import "../../../base/StrategyBaseClaimable.sol";

/**
* This strategy is for the mixToken vault, i.e., the underlying token is mixToken. It is not to accept
* stable coins. It will farm the CRV crop. For liquidation, it swaps CRV into USDT and uses USDT
* to produce mixToken.
*/
contract CRVStrategyUST is StrategyBaseClaimable {

  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  event Liquidating(uint256 amount);
  event ProfitsNotCollected();

  // crvUST
  address public pool;
  address public mintr;
  address public crv;

  address public weth;
  address public usdt;
  address public curveDepositUST;

  address public uni;

  uint256 maxUint = uint256(~0);
  address[] public uniswap_CRV2USDT;

  // a flag for disabling selling for simplified emergency exit
  bool public sell = true;
  // minimum CRV amount to be liquidation
  uint256 public sellFloor = 1e16;

  constructor(
    address _storage,
    address _vault,
    address _underlying,
    address _gauge,
    address _mintr,
    address _crv,
    address _weth,
    address _usdt,
    address _curveDepositUST,
    address _uniswap
  )
  StrategyBaseClaimable(_storage, _underlying, _vault, _crv, _crv, _uniswap) public {
    require(IVault(_vault).underlying() == _underlying, "vault does not support ustCRV");
    pool = _gauge;
    mintr = _mintr;
    crv = _crv;
    weth = _weth;
    usdt = _usdt;
    curveDepositUST = _curveDepositUST;
    uni = _uniswap;
    // liquidating to usdt and we could deposit it (instead of going one more step to ust)
    uniswap_CRV2USDT = [crv, weth, usdt];
    // set these tokens to be not salvageable
    unsalvagableTokens[underlying] = true;
    unsalvagableTokens[crv] = true;
    allowedRewardClaimable = true;
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  /**
  * Salvages a token. We should not be able to salvage CRV and underlying.
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
    Gauge(pool).withdraw(
      Math.min(Gauge(pool).balanceOf(address(this)), amount)
    );
  }

  /**
  * Withdraws the underlying tokens to the pool in the specified amount.
  */
  function withdrawToVault(uint256 amountUnderlying) external restricted {
    withdrawUnderlyingFromPool(amountUnderlying);
    if (IERC20(underlying).balanceOf(address(this)) < amountUnderlying) {
      claimAndLiquidateCrv();
    }
    uint256 toTransfer = Math.min(IERC20(underlying).balanceOf(address(this)), amountUnderlying);
    IERC20(underlying).safeTransfer(vault, toTransfer);
  }

  /**
  * Withdraws all the underlying tokens to the pool.
  */
  function withdrawAllToVault() external restricted {
    claimAndLiquidateCrv();
    withdrawUnderlyingFromPool(maxUint);
    uint256 balance = IERC20(underlying).balanceOf(address(this));
    IERC20(underlying).safeTransfer(vault, balance);
  }

  /**
  * Invests all the underlying into the pool that mints crops (CRV)
  */
  function investAllUnderlying() public restricted {
    uint256 underlyingBalance = IERC20(underlying).balanceOf(address(this));
    if (underlyingBalance > 0) {
      IERC20(underlying).safeApprove(pool, 0);
      IERC20(underlying).safeApprove(pool, underlyingBalance);
      Gauge(pool).deposit(underlyingBalance);
    }
  }

  /**
  * Claims the CRV crop, converts it to USDT on Uniswap, and then uses USDT to mint underlying using the
  * Curve protocol.
  */
  function claimAndLiquidateCrv() internal {
    if (!sell) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected();
      return;
    }
    _getReward();

    uint256 rewardBalance = IERC20(crv).balanceOf(address(this));

    if (rewardBalance < sellFloor) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected();
      return;
    }

    notifyProfitInRewardToken(rewardBalance);
    uint256 crvBalance = IERC20(crv).balanceOf(address(this));

    if (crvBalance > 0) {
      emit Liquidating(crvBalance);
      IERC20(crv).safeApprove(uni, 0);
      IERC20(crv).safeApprove(uni, crvBalance);
      // we can accept 1 as the minimum because this will be called only by a trusted worker
      IUniswapV2Router02(uni).swapExactTokensForTokens(
        crvBalance, 1, uniswap_CRV2USDT, address(this), block.timestamp
      );

      if(IERC20(usdt).balanceOf(address(this)) > 0) {
        ustCRVFromUSDT();
      }
    }
  }

  /**
  * Claims the rewards.
  */
  function _getReward() internal {
    Mintr(mintr).mint(pool);
  }

  /**
  * Claims and liquidates CRV into underlying, and then invests all underlying.
  */
  function doHardWork() public restricted {
    claimAndLiquidateCrv();
    investAllUnderlying();
  }

  /**
  * Investing all underlying.
  */
  function investedUnderlyingBalance() public view returns (uint256) {
    return Gauge(pool).balanceOf(address(this)).add(
      IERC20(underlying).balanceOf(address(this))
    );
  }

  /**
  * Converts all USDT to underlying using the CRV protocol.
  */
  function ustCRVFromUSDT() internal {
    uint256 usdtBalance = IERC20(usdt).balanceOf(address(this));
    if (usdtBalance > 0) {
      IERC20(usdt).safeApprove(curveDepositUST, 0);
      IERC20(usdt).safeApprove(curveDepositUST, usdtBalance);

      // we can accept 0 as minimum, this will be called only by trusted roles
      uint256 minimum = 0;
      ICurveBUSDDeposit(curveDepositUST).add_liquidity([0, 0, 0, usdtBalance], minimum);
      // now we have ustCRV
    }
  }

  /**
  * Can completely disable claiming CRV rewards and selling. Good for emergency withdraw in the
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
}
