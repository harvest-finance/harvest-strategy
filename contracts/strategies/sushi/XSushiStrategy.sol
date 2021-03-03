pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../base/inheritance/Controllable.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "./interface/SushiBar.sol";
import "../aave/AaveInteractor.sol";

contract XSushiStrategy is IStrategy, Controllable, AaveInteractor {

  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  bool public constant depositArbCheck = true;

  address public xsushi;
  address public underlying; // sushi
  address public vault;
  mapping(address => bool) public unsalvagableTokens;
  uint256 public aaveWrapCap;

  modifier restricted() {
    require(msg.sender == vault || msg.sender == address(controller()) || msg.sender == address(governance()),
      "The sender has to be the controller or vault or governance");
    _;
  }

  constructor(
    address _storage,
    address _vault,
    address _underlying,
    address _xsushi,
    address _lendingPoolProvider,
    address _protocolDataProvider,
    uint256 _aaveWrapCap
  ) Controllable(_storage) AaveInteractor(_xsushi, _lendingPoolProvider, _protocolDataProvider) public {
    require(IVault(_vault).underlying() == _underlying, "vault does not support sushi");
    xsushi = _xsushi;
    underlying = _underlying;
    vault = _vault;
    unsalvagableTokens[_underlying] = true;
    unsalvagableTokens[_xsushi] = true;
    unsalvagableTokens[aTokenAddress] = true;
    aaveWrapCap = _aaveWrapCap;
  }

  function setAaveCap(uint256 _newCap) public onlyGovernance {
    aaveWrapCap = _newCap;
  }

  function wrap() public restricted {
    uint256 balance = IERC20(underlying).balanceOf(address(this));
    if (balance > 0) {
      IERC20(underlying).safeApprove(xsushi, 0);
      IERC20(underlying).safeApprove(xsushi, balance);
      SushiBar(xsushi).enter(balance);
    }

    uint256 xBalance = IERC20(xsushi).balanceOf(address(this));
    if(xBalance > 0) {
      _aaveDeposit(xBalance);
    }
  }

  function unwrap() public restricted {
    uint256 aBalance = IERC20(aTokenAddress).balanceOf(address(this));
    if(aBalance > 0){
      _aaveWithdraw(aBalance);
    }

    uint256 balance = IERC20(xsushi).balanceOf(address(this));
    if (balance > 0) {
      SushiBar(xsushi).leave(balance);
    }
  }

  function withdrawAllToVault() external restricted {
    unwrap();
    uint256 balance = IERC20(underlying).balanceOf(address(this));
    if (balance > 0) {
      IERC20(underlying).safeTransfer(vault, balance);
    }
  }

  function withdrawToVault(uint256 amountUnderlying) external restricted {
    // this is similarly gas-efficient as making the calculation for exact xsushi to withdraw
    unwrap();
    require(IERC20(underlying).balanceOf(address(this)) >= amountUnderlying, "insufficient balance for the withdrawal");
    IERC20(underlying).safeTransfer(vault, amountUnderlying);
    wrap();
  }

  function salvage(address recipient, address token, uint256 amount) public onlyGovernance {
    // To make sure that governance cannot come in and take away the coins
    require(!unsalvagableTokens[token], "token is defined as not salvageable");
    IERC20(token).safeTransfer(recipient, amount);
  }

  function doHardWork() public restricted {
    // this should not be needed ever
    // xsushi appreciates on its own
    unwrap();
    wrap();
  }

  function investAllUnderlying() public restricted {
    // the method is implemented just for consistency
    wrap();
  }

  function investedUnderlyingBalance() external view returns (uint256) {
    // adjusted xsushi code for exit
    // https://etherscan.io/address/0x8798249c2e607446efb7ad49ec89dd1865ff4272#code
    uint256 axSushi = IERC20(aTokenAddress).balanceOf(address(this));
    uint256 share = IERC20(xsushi).balanceOf(address(this)).add(axSushi);
    uint256 totalShares = IERC20(xsushi).totalSupply();
    uint256 sushiBalance = IERC20(underlying).balanceOf(address(this));
    return (share.mul(IERC20(underlying).balanceOf(xsushi)).div(totalShares)).add(sushiBalance);
  }
}
