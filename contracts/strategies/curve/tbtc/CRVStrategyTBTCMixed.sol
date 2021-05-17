pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../base/interface/curve/Gauge.sol";
import "../../../base/interface/curve/ICurveSTETHDeposit.sol";
import "../../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../../base/interface/IStrategy.sol";
import "../../../base/interface/IVault.sol";
import "../../../base/interface/weth/Weth9.sol";
import "../../../base/StrategyBase.sol";
import "../../../base/inheritance/RewardTokenProfitNotifier.sol";
import "./ICurveTBTC.sol";


contract CRVStrategyTBTCMixed is IStrategy, RewardTokenProfitNotifier {

  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  event Liquidating(address rewardToken, uint256 amount);
  event ProfitsNotCollected(address rewardToken);

  // the mixed token
  address public underlying;
  address public pool;
  address public mintr;
  address public crv;

  address public curve;
  address public weth;
  address public wbtc;

  address public uni;

  // these tokens cannot be claimed by the governance
  mapping(address => bool) public unsalvagableTokens;

  address public vault;

  uint256 maxUint = uint256(~0);
  address[] public uniswap_CRV2WBTC;

  // a flag for disabling selling for simplified emergency exit
  bool public sell = true;

  // minimum CRV amount to be liquidated
  uint256 public sellFloor = 1e18;

  modifier restricted() {
    require(msg.sender == vault || msg.sender == controller()
      || msg.sender == governance(),
      "The sender has to be the controller, governance, or vault");
    _;
  }

  constructor(
    address _storage,
    address _vault,
    address _underlying,
    address _gauge,
    address _mintr,
    address _crv,
    address _curve,
    address _weth,
    address _wbtc,
    address _uniswap
  )
  RewardTokenProfitNotifier(_storage, _crv) public {
    require(IVault(_vault).underlying() == _underlying, "vault does not support TBTC-mixed");
    vault = _vault;
    underlying = _underlying;
    pool = _gauge;
    mintr = _mintr;
    crv = _crv;
    curve = _curve;
    weth = _weth;
    wbtc = _wbtc;
    uni = _uniswap;
    uniswap_CRV2WBTC = [crv, weth, wbtc];
    // set these tokens to be not salvageable
    unsalvagableTokens[underlying] = true;
    unsalvagableTokens[crv] = true;
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  /**
  * Salvages a token. We should not be able to salvage CRV and the mixed token (underlying).
  */
  function salvage(address recipient, address token, uint256 amount) public onlyGovernance {
    // To make sure that governance cannot come in and take away the coins
    require(!unsalvagableTokens[token], "token is defined as not salvageable");
    IERC20(token).safeTransfer(recipient, amount);
  }

  /**
  * Withdraws the mixed token from the investment pool that mints crops.
  */
  function withdrawMixedFromPool(uint256 amount) internal {
    Gauge(pool).withdraw(
      Math.min(Gauge(pool).balanceOf(address(this)), amount)
    );
  }

  /**
  * Withdraws the the mixed token tokens to the pool in the specified amount.
  */
  function withdrawToVault(uint256 amountUnderlying) external restricted {
    withdrawMixedFromPool(amountUnderlying);
    if (IERC20(underlying).balanceOf(address(this)) < amountUnderlying) {
      claimAndLiquidateCrv();
    }
    uint256 toTransfer = Math.min(IERC20(underlying).balanceOf(address(this)), amountUnderlying);
    IERC20(underlying).safeTransfer(vault, toTransfer);
  }

  /**
  * Withdraws all the the mixed token tokens to the pool.
  */
  function withdrawAllToVault() external restricted {
    claimAndLiquidateCrv();
    withdrawMixedFromPool(maxUint);
    uint256 balance = IERC20(underlying).balanceOf(address(this));
    IERC20(underlying).safeTransfer(vault, balance);
  }

  /**
  * Invests all the underlying the mixed token into the pool that mints crops.
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
  * Claims the CRV, converts them into WBTC on Uniswap, and then uses WBTC to mint the mixed token using the
  * Curve protocol.
  */
  function claimAndLiquidateCrv() internal {
    if (!sell) {
      emit ProfitsNotCollected(crv);
    } else {
      Mintr(mintr).mint(pool);
      uint256 crvBalance = IERC20(crv).balanceOf(address(this));
      if (crvBalance < sellFloor) {
        emit ProfitsNotCollected(crv);
      } else {
        notifyProfitInRewardToken(crvBalance);
        crvBalance = IERC20(crv).balanceOf(address(this));
        emit Liquidating(crv, crvBalance);

        IERC20(crv).safeApprove(uni, 0);
        IERC20(crv).safeApprove(uni, crvBalance);
        // we can accept 1 as the minimum because this will be called only by a trusted worker
        IUniswapV2Router02(uni).swapExactTokensForTokens(
          crvBalance, 1, uniswap_CRV2WBTC, address(this), block.timestamp
        );
      }
    }

    uint256 wbtcBalanceAfter = IERC20(wbtc).balanceOf(address(this));
    if (wbtcBalanceAfter > 0) {
      curveMixedFromWBTC();
    }
  }

  /**
  * Claims and liquidates CRV into the mixed token, and then invests all underlying.
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
  * Uses the Curve protocol to convert the underlying asset into the mixed token.
  */
  function curveMixedFromWBTC() internal {
    uint256 wbtcBalance = IERC20(wbtc).balanceOf(address(this));
    if (wbtcBalance > 0) {
      IERC20(wbtc).safeApprove(curve, 0);
      IERC20(wbtc).safeApprove(curve, wbtcBalance);
      uint256 minimum = 0;
      ICurveTBTC(curve).add_liquidity([0, 0, wbtcBalance, 0], minimum);
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

  function setLiquidationPath(address[] memory _crvPath) public onlyGovernance {
    uniswap_CRV2WBTC = _crvPath;
  }
}
