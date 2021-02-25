pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../base/interface/curve/Gauge.sol";
import "../../../base/interface/curve/ICurveAnkrETHDeposit.sol";
import "../../../base/interface/IStrategy.sol";
import "../../../base/interface/IVault.sol";
import "../../../base/interface/ILiquidatorRegistry.sol";
import "../../../base/interface/ILiquidator.sol";
import "../../../base/interface/weth/Weth9.sol";

import "../../../base/StrategyBaseUL.sol";

/**
* This strategy is for the mixToken vault, i.e., the underlying token is mixToken. It is not to accept
* stable coins. It will farm the CRV crop. For liquidation, it swaps CRV into ETH and uses ETH
* to produce mixToken.
*/
contract CRVStrategyAnkrETH is StrategyBaseUL {

  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  event Liquidating(uint256 amount);
  event ProfitsNotCollected();

  // ankrCRV
  address public pool;
  address public mintr;
  address public crv;
  address public onx;
  address public ankr;

  address public weth;
  address public curveDepositAnkrETH;

  address public liquidatorRegistry;
  address public liquidator;

  uint256 maxUint = uint256(~0);

  address[] public rewardTokens;
  // a flag for disabling selling for simplified emergency exit
  mapping (address => bool) public sell;
  bool public globalSell = true;
  // minimum amount to be liquidation
  mapping (address => uint256) public sellFloor;
  mapping (address => bytes32) public dex;
  mapping (address => address[]) public liquidationPath;

  constructor(
    address _storage,
    address _vault,
    address _underlying,
    address _gauge,
    address _mintr,
    address _crv,
    address _onx,
    address _ankr,
    address _weth,
    address _curveDepositAnkrETH,
    address _universalLiquidatorRegistry
  )
  StrategyBaseUL(_storage, _underlying, _vault, _weth, _universalLiquidatorRegistry) public {
    require(IVault(_vault).underlying() == _underlying, "vault does not support ankrCRV");
    pool = _gauge;
    mintr = _mintr;
    crv = _crv;
    onx = _onx;
    ankr = _ankr;
    weth = _weth;
    curveDepositAnkrETH = _curveDepositAnkrETH;
    liquidatorRegistry = _universalLiquidatorRegistry;
    liquidator = universalLiquidator();

    globalSell = true;

    unsalvagableTokens[crv] = true;
    sell[crv] = true;
    sellFloor[crv] = 1e16;
    dex[crv] = bytes32(uint256(keccak256("uni")));
    liquidationPath[crv] = ILiquidatorRegistry(liquidatorRegistry).getPath(dex[crv], crv, weth);

    unsalvagableTokens[onx] = true;
    sell[onx] = true;
    sellFloor[onx] = 1e16;
    dex[onx] = bytes32(uint256(keccak256("sushi")));
    liquidationPath[onx] = ILiquidatorRegistry(liquidatorRegistry).getPath(dex[onx], onx, weth);

    unsalvagableTokens[ankr] = true;
    sell[ankr] = true;
    sellFloor[ankr] = 1e16;
    dex[ankr] = bytes32(uint256(keccak256("uni")));
    liquidationPath[ankr] = ILiquidatorRegistry(liquidatorRegistry).getPath(dex[ankr], ankr, weth);

    rewardTokens.push(crv);
    rewardTokens.push(onx);
    rewardTokens.push(ankr);
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

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
    require(IERC20(underlying).balanceOf(address(this)) >= amountUnderlying, "insufficient balance for the withdrawal");
    IERC20(underlying).safeTransfer(vault, amountUnderlying);
  }

  /**
  * Withdraws all the underlying tokens to the pool.
  */
  function withdrawAllToVault() external restricted {
    claimAndLiquidateReward();
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
  * Needed to be able to convert WETH into ETH.
  */
  function() external payable {}

  /**
  * Claims the CRV crop, converts it to ETH on Uniswap, and then uses ETH to mint underlying using the
  * Curve protocol.
  */
  function claimAndLiquidateReward() internal {
    if (!globalSell) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected(address(0x0));
      return;
    }
    Mintr(mintr).mint(pool);

    // rewardTokens, ellFloor, sell, uniswapLiquidationPath
    // All sell to WETH
    for(uint256 i = 0; i < rewardTokens.length; i++){
      address rewardToken = rewardTokens[i];
      uint256 rewardBalance = IERC20(rewardToken).balanceOf(address(this));
      if (rewardBalance < sellFloor[rewardToken] || !sell[rewardToken]) {
        // Profits can be disabled for possible simplified and rapid exit
        emit ProfitsNotCollected(rewardToken);
      } else {
        emit Liquidating(rewardToken, rewardBalance);
        IERC20(rewardToken).safeApprove(liquidator, 0);
        IERC20(rewardToken).safeApprove(liquidator, rewardBalance);
        // we can accept 1 as the minimum because this will be called only by a trusted worker
        ILiquidator(liquidator).swapTokenOnDEX(rewardBalance, 1, address(this), dex[rewardToken], liquidationPath[rewardToken]);
      }
    }

    uint256 wethRewardBalance = IERC20(weth).balanceOf(address(this));

    notifyProfitInRewardToken(wethRewardBalance);

    wethRewardBalance = IERC20(weth).balanceOf(address(this));

    if(IERC20(weth).balanceOf(address(this)) > 0) {
      IERC20(weth).safeApprove(weth, 0);
      IERC20(weth).safeApprove(weth, wethRewardBalance);
      WETH9(weth).withdraw(wethRewardBalance);
      ankrCRVFromETH();
    }
  }

  /**
  * Claims and liquidates CRV into underlying, and then invests all underlying.
  */
  function doHardWork() public restricted {
    claimAndLiquidateReward();
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
  * Converts all ETH to underlying using the CRV protocol.
  */
  function ankrCRVFromETH() internal {
    uint256 ethBalance = address(this).balance;
    if (ethBalance > 0) {
      // we can accept 0 as minimum, this will be called only by trusted roles
      uint256 minimum = 0;
      ICurveAnkrETHDeposit(curveDepositAnkrETH).add_liquidity.value(ethBalance)([ethBalance, 0], minimum);
      // now we have ankrCRV
    }
  }

  /**
  * Can completely disable claiming reward rewards and selling. Good for emergency withdraw in the
  * simplest possible way.
  */
  function setSell(address rt, bool s) public onlyGovernance {
    sell[rt] = s;
  }

  function setGlobalSell(bool s) public onlyGovernance {
    globalSell = s;
  }

  /**
  * Sets the minimum amount of CRV needed to trigger a sale.
  */
  function setSellFloor(address rt, uint256 floor) public onlyGovernance {
    sellFloor[rt] = floor;
  }

  function setRewardTokens(address[] memory rts) public onlyGovernance {
    rewardTokens = rts;
  }
}
