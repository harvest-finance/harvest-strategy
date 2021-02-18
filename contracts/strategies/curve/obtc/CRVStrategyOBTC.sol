pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../base/interface/curve/Gauge.sol";
import "../../../base/interface/curve/ICurveOBTCDeposit.sol";
import "../../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../../base/interface/IStrategy.sol";
import "../../../base/interface/IVault.sol";

import "../../../base/StrategyBase.sol";

/**
* This strategy is for the mixToken vault, i.e., the underlying token is mixToken. It is not to accept
* stable coins. It will farm the CRV crop. For liquidation, it swaps CRV into WBTC and uses WBTC
* to produce mixToken.
*/
contract CRVStrategyOBTC is StrategyBase {

  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  event Liquidating(address token, uint256 amount);
  event ProfitsNotCollected(address token);

  // crvOBTC
  address public pool;
  address public mintr;
  address public crv;
  address public bor;

  address public curve;
  address public weth;
  address public wbtc;
  address public curveDepositOBTC;

  address public uni;
  address public sushi;

  // these tokens cannot be claimed by the governance
  mapping(address => bool) public unsalvagableTokens;

  uint256 maxUint = uint256(~0);
  address[] public uniswap_CRV2WETH;
  address[] public sushiswap_BOR2WETH;
  address[] public uniswap_WETH2WBTC;

  // a flag for disabling selling for simplified emergency exit
  bool public sell = true;
  // minimum CRV amount to be liquidation
  uint256 public sellFloorCrv = 1e17;
  uint256 public sellFloorBor = 1e15;

  constructor(
    address _storage,
    address _vault,
    address _underlying,
    address _gauge,
    address _mintr,
    address _crv,
    address _bor,
    address _curve,
    address _weth,
    address _wbtc,
    address _curveDepositOBTC,
    address _uniswap,
    address _sushiswap
  )
  StrategyBase(_storage, _underlying, _vault, _weth, _uniswap) public {
    require(IVault(_vault).underlying() == _underlying, "vault does not support obtcCRV");
    pool = _gauge;
    mintr = _mintr;
    crv = _crv;
    bor = _bor;
    curve = _curve;
    weth = _weth;
    wbtc = _wbtc;
    curveDepositOBTC = _curveDepositOBTC;
    uni = _uniswap;
    sushi = _sushiswap;
    uniswap_CRV2WETH = [crv, weth];
    sushiswap_BOR2WETH = [bor, weth];
    uniswap_WETH2WBTC = [weth, wbtc];
    // set these tokens to be not salvageable
    unsalvagableTokens[underlying] = true;
    unsalvagableTokens[crv] = true;
    unsalvagableTokens[bor] = true;
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
  * Claims the CRV crop, converts it to WBTC on Uniswap, and then uses WBTC to mint underlying using the
  * Curve protocol.
  */
  function claimAndLiquidateCrv() internal {
    if (!sell) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected(0x0000000000000000000000000000000000000000);
      return;
    }
    Mintr(mintr).mint(pool);

    uint256 crvBalance = IERC20(crv).balanceOf(address(this));
    if (crvBalance < sellFloorCrv) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected(crv);
    } else {
      emit Liquidating(crv, crvBalance);
      IERC20(crv).safeApprove(uni, 0);
      IERC20(crv).safeApprove(uni, crvBalance);
      // we can accept 1 as the minimum because this will be called only by a trusted worker
      IUniswapV2Router02(uni).swapExactTokensForTokens(
        crvBalance, 1, uniswap_CRV2WETH, address(this), block.timestamp
      );
    }

    uint256 borBalance = IERC20(bor).balanceOf(address(this));
    if (borBalance < sellFloorBor) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected(bor);
    } else {
      emit Liquidating(bor, borBalance);
      IERC20(bor).safeApprove(sushi, 0);
      IERC20(bor).safeApprove(sushi, borBalance);
      // we can accept 1 as the minimum because this will be called only by a trusted worker
      IUniswapV2Router02(sushi).swapExactTokensForTokens(
        borBalance, 1, sushiswap_BOR2WETH, address(this), block.timestamp
      );
    }

    uint256 wethBalance = IERC20(weth).balanceOf(address(this));
    if( wethBalance > 0 ) {

      notifyProfitInRewardToken(wethBalance);

      uint256 remainingWethBalance = IERC20(weth).balanceOf(address(this));
      IERC20(weth).safeApprove(uni, 0);
      IERC20(weth).safeApprove(uni, remainingWethBalance);
      // we can accept 1 as the minimum because this will be called only by a trusted worker
      IUniswapV2Router02(uni).swapExactTokensForTokens(
        remainingWethBalance, 1, uniswap_WETH2WBTC, address(this), block.timestamp
      );

      if(IERC20(wbtc).balanceOf(address(this)) > 0) {
        obtcCRVFromWbtc();
      }
    }
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
  * Converts all WBTC to underlying using the CRV protocol.
  */
  function obtcCRVFromWbtc() internal {
    uint256 wbtcBalance = IERC20(wbtc).balanceOf(address(this));
    if (wbtcBalance > 0) {
      IERC20(wbtc).safeApprove(curveDepositOBTC, 0);
      IERC20(wbtc).safeApprove(curveDepositOBTC, wbtcBalance);

      // we can accept 0 as minimum, this will be called only by trusted roles
      uint256 minimum = 0;
      ICurveOBTCDeposit(curveDepositOBTC).add_liquidity([0, 0, wbtcBalance, 0], minimum);
      // now we have obtcCRV
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
  function setSellFloor(uint256 _floorCrv, uint256 _floorBor) public onlyGovernance {
    sellFloorCrv = _floorCrv;
    sellFloorBor = _floorBor;
  }
}
