pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/inheritance/RewardTokenProfitNotifier.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "../../base/interface/uniswap/IUniswapV2Router02.sol";
import "./interface/IdleToken.sol";
import "./interface/IIdleTokenHelper.sol";
import "./interface/IStakedAave.sol";

contract IdleFinanceStrategy is IStrategy, RewardTokenProfitNotifier {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  event ProfitsNotCollected(address);
  event Liquidating(address, uint256);

  address public referral;
  IERC20 public underlying;
  address public idleUnderlying;
  uint256 public virtualPrice;
  IIdleTokenHelper public idleTokenHelper;

  address public vault;
  address public stkaave;

  address[] public rewardTokens;
  mapping(address => address[]) public reward2WETH;
  address[] public WETH2underlying;
  mapping(address => bool) public sell;
  mapping(address => bool) public useUni;

  address public constant uniswapRouterV2 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public constant sushiswapRouterV2 = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  bool public claimAllowed;
  bool public protected;

  bool public allowedRewardClaimable = false;
  address public multiSig = address(0xF49440C1F012d041802b25A73e5B0B9166a75c02);

  // These tokens cannot be claimed by the controller
  mapping (address => bool) public unsalvagableTokens;

  modifier restricted() {
    require(msg.sender == vault || msg.sender == address(controller()) || msg.sender == address(governance()),
      "The sender has to be the controller or vault or governance");
    _;
  }

  modifier onlyMultiSigOrGovernance() {
    require(msg.sender == multiSig || msg.sender == governance(), "The sender has to be multiSig or governance");
    _;
  }

  modifier updateVirtualPrice() {
    if (protected) {
      require(virtualPrice <= idleTokenHelper.getRedeemPrice(idleUnderlying), "virtual price is higher than needed");
    }
    _;
    virtualPrice = idleTokenHelper.getRedeemPrice(idleUnderlying);
  }

  constructor(
    address _storage,
    address _underlying,
    address _idleUnderlying,
    address _vault,
    address _stkaave
  ) RewardTokenProfitNotifier(_storage, weth) public {
    stkaave = _stkaave;
    underlying = IERC20(_underlying);
    idleUnderlying = _idleUnderlying;
    vault = _vault;
    protected = true;

    // set these tokens to be not salvagable
    unsalvagableTokens[_underlying] = true;
    unsalvagableTokens[_idleUnderlying] = true;
    for (uint256 i = 0; i < rewardTokens.length; i++) {
      address token = rewardTokens[i];
      unsalvagableTokens[token] = true;
    }
    referral = address(0xf00dD244228F51547f0563e60bCa65a30FBF5f7f);
    claimAllowed = true;

    idleTokenHelper = IIdleTokenHelper(0x04Ce60ed10F6D2CfF3AA015fc7b950D13c113be5);
    virtualPrice = idleTokenHelper.getRedeemPrice(idleUnderlying);
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  function setReferral(address _newRef) public onlyGovernance {
    referral = _newRef;
  }

  /**
  * The strategy invests by supplying the underlying token into IDLE.
  */
  function investAllUnderlying() public restricted updateVirtualPrice {
    uint256 balance = underlying.balanceOf(address(this));
    underlying.safeApprove(address(idleUnderlying), 0);
    underlying.safeApprove(address(idleUnderlying), balance);
    IIdleTokenV3_1(idleUnderlying).mintIdleToken(balance, true, referral);
  }

  /**
  * Exits IDLE and transfers everything to the vault.
  */
  function withdrawAllToVault() external restricted updateVirtualPrice {
    withdrawAll();
    IERC20(address(underlying)).safeTransfer(vault, underlying.balanceOf(address(this)));
  }

  /**
  * Withdraws all from IDLE
  */
  function withdrawAll() internal {
    uint256 balance = IERC20(idleUnderlying).balanceOf(address(this));

    // this automatically claims the crops
    IIdleTokenV3_1(idleUnderlying).redeemIdleToken(balance);

    liquidateRewards();
  }

  function withdrawToVault(uint256 amountUnderlying) public restricted {
    // this method is called when the vault is missing funds
    // we will calculate the proportion of idle LP tokens that matches
    // the underlying amount requested
    uint256 balanceBefore = underlying.balanceOf(address(this));
    uint256 totalIdleLpTokens = IERC20(idleUnderlying).balanceOf(address(this));
    uint256 totalUnderlyingBalance = totalIdleLpTokens.mul(virtualPrice).div(1e18);
    uint256 ratio = amountUnderlying.mul(1e18).div(totalUnderlyingBalance);
    uint256 toRedeem = totalIdleLpTokens.mul(ratio).div(1e18);
    IIdleTokenV3_1(idleUnderlying).redeemIdleToken(toRedeem);
    uint256 balanceAfter = underlying.balanceOf(address(this));
    underlying.safeTransfer(vault, balanceAfter.sub(balanceBefore));
  }

  /**
  * Withdraws all assets, liquidates COMP, and invests again in the required ratio.
  */
  function doHardWork() public restricted updateVirtualPrice {
    if (claimAllowed) {
      claim();
    }
    liquidateRewards();

    // this updates the virtual price
    investAllUnderlying();

    // state of supply/loan will be updated by the modifier
  }

  /**
  * Salvages a token.
  */
  function salvage(address recipient, address token, uint256 amount) public onlyGovernance {
    // To make sure that governance cannot come in and take away the coins
    require(!unsalvagableTokens[token], "token is defined as not salvagable");
    IERC20(token).safeTransfer(recipient, amount);
  }

  function claim() internal {
    IIdleTokenV3_1(idleUnderlying).redeemIdleToken(0);

    uint256 claimableAave = IStakedAave(stkaave).stakerRewardsToClaim(address(this));
    if (claimableAave > 0) {
      IStakedAave(stkaave).claimRewards(address(this), claimableAave);
    }
  }

  function liquidateRewards() internal {
    for (uint256 i=0;i<rewardTokens.length;i++) {
      address token = rewardTokens[i];
      if (!sell[token]) {
        // Profits can be disabled for possible simplified and rapid exit
        emit ProfitsNotCollected(token);
        continue;
      }

      uint256 balance = IERC20(token).balanceOf(address(this));
      if (balance > 0) {
        emit Liquidating(token, balance);
        address routerV2;
        if(useUni[token]) {
          routerV2 = uniswapRouterV2;
        } else {
          routerV2 = sushiswapRouterV2;
        }
        IERC20(token).safeApprove(routerV2, 0);
        IERC20(token).safeApprove(routerV2, balance);
        // we can accept 1 as the minimum because this will be called only by a trusted worker
        IUniswapV2Router02(routerV2).swapExactTokensForTokens(
          balance, 1, reward2WETH[token], address(this), block.timestamp
        );
      }
    }

    uint256 wethBalance = IERC20(weth).balanceOf(address(this));
    notifyProfitInRewardToken(wethBalance);

    uint256 remainingWethBalance = IERC20(weth).balanceOf(address(this));

    if (remainingWethBalance > 0) {
      emit Liquidating(weth, remainingWethBalance);
      address routerV2;
      if(useUni[address(underlying)]) {
        routerV2 = uniswapRouterV2;
      } else {
        routerV2 = sushiswapRouterV2;
      }
      IERC20(weth).safeApprove(routerV2, 0);
      IERC20(weth).safeApprove(routerV2, remainingWethBalance);
      // we can accept 1 as the minimum because this will be called only by a trusted worker
      IUniswapV2Router02(routerV2).swapExactTokensForTokens(
        remainingWethBalance, 1, WETH2underlying, address(this), block.timestamp
      );
    }
  }

  /**
  * Returns the current balance. Ignores COMP that was not liquidated and invested.
  */
  function investedUnderlyingBalance() public view returns (uint256) {
    // NOTE: The use of virtual price is okay for appreciating assets inside IDLE,
    // but would be wrong and exploitable if funds were lost by IDLE, indicated by
    // the virtualPrice being greater than the token price.
    if (protected) {
      require(virtualPrice <= idleTokenHelper.getRedeemPrice(idleUnderlying), "virtual price is higher than needed");
    }
    uint256 invested = IERC20(idleUnderlying).balanceOf(address(this)).mul(virtualPrice).div(1e18);
    return invested.add(IERC20(underlying).balanceOf(address(this)));
  }

  function setLiquidation(address _token, bool _sell) public onlyGovernance {
     sell[_token] = _sell;
  }

  function setClaimAllowed(bool _claimAllowed) public onlyGovernance {
    claimAllowed = _claimAllowed;
  }

  function setProtected(bool _protected) public onlyGovernance {
    protected = _protected;
  }

  function setMultiSig(address _address) public onlyGovernance {
    multiSig = _address;
  }

  function setRewardClaimable(bool flag) public onlyGovernance {
    allowedRewardClaimable = flag;
  }

  // reward claiming by multiSig. Only the stkAave rewards are claimable!
  function claimReward() public onlyMultiSigOrGovernance {
    require(allowedRewardClaimable, "reward claimable is not allowed");
    claim();
    uint256 stkAaveBalance = IERC20(stkaave).balanceOf(address(this));
    if (stkAaveBalance > 0){
      IERC20(stkaave).safeTransfer(msg.sender, stkAaveBalance);
    }
  }
}
