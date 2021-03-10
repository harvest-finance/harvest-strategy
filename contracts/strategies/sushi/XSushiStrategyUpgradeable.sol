pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "../../base/interface/IController.sol";
import "../../base/inheritance/ControllableInit.sol";
import "../../base/upgradability/BaseUpgradeableStrategy.sol";
import "../aave/AaveInteractorInit.sol";
import "./interface/SushiBar.sol";


contract XSushiStrategyUpgradeable is IStrategy, Initializable, BaseUpgradeableStrategy, AaveInteractorInit {

  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  bytes32 internal constant _X_SUSHI_SLOT = 0x1c8fae71a564f5ee0ef3c480d3c56ad130c3dbb93e02cc33ab794f7a7f21ea57;
  bytes32 internal constant _AAVE_WRAP_CAP_SLOT = 0x01682d4ae8f38d11336fb93e5996230fbcbe142ceb30f4641320e2ad3ce20efe;

  constructor() public {
    require(_X_SUSHI_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.xsushi")) - 1));
    require(_AAVE_WRAP_CAP_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.aaveWrapCap")) - 1));
  }

  function initializeStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _xsushi,
    address _lendingPoolProvider,
    address _protocolDataProvider,
    uint256 _aaveWrapCap
  ) public initializer {
    BaseUpgradeableStrategy.initialize(
      _storage,
      _underlying,
      _vault,
      address(0), // unused
      address(0), // unused
      0, // unused
      0, // unused
      false, // unused
      0, // unused
      12 hours
    );
    AaveInteractorInit.initialize(
      _xsushi, _lendingPoolProvider, _protocolDataProvider
    );
    require(IVault(_vault).underlying() == _underlying, "vault does not support sushi");
    setAddress(_X_SUSHI_SLOT, _xsushi);
    setAaveCap(_aaveWrapCap);
  }

  function xsushi() public view returns (address) {
    return getAddress(_X_SUSHI_SLOT);
  }

  function depositArbCheck() public view returns (bool) {
    return true;
  }

  function unsalvagableTokens(address _token) public view returns(bool) {
    return _token == underlying() || _token == xsushi() || _token == aTokenAddress();
  }

  function setAaveCap(uint256 _newCap) public onlyGovernance {
    setUint256(_AAVE_WRAP_CAP_SLOT, _newCap);
  }

  function aaveCap() public view returns(uint256) {
    return getUint256(_AAVE_WRAP_CAP_SLOT);
  }

  function wrap() public restricted {
    uint256 balance = IERC20(underlying()).balanceOf(address(this));
    if (balance > 0) {
      IERC20(underlying()).safeApprove(xsushi(), 0);
      IERC20(underlying()).safeApprove(xsushi(), balance);
      SushiBar(xsushi()).enter(balance);
    }

    uint256 xBalance = IERC20(xsushi()).balanceOf(address(this));
    uint256 alreadyDeposited = IERC20(aTokenAddress()).balanceOf(address(this));
    if (alreadyDeposited < aaveCap()) {
      uint256 toDeposit = Math.min(xBalance, aaveCap().sub(alreadyDeposited));
      if (toDeposit > 0) {
        _aaveDeposit(toDeposit);
      }
    }
  }

  function unwrap() public restricted {
    uint256 aBalance = IERC20(aTokenAddress()).balanceOf(address(this));
    if (aBalance > 0) {
      _aaveWithdraw(aBalance);
    }

    uint256 balance = IERC20(xsushi()).balanceOf(address(this));
    if (balance > 0) {
      SushiBar(xsushi()).leave(balance);
    }
  }

  function withdrawAllToVault() external restricted {
    unwrap();
    uint256 balance = IERC20(underlying()).balanceOf(address(this));
    if (balance > 0) {
      IERC20(underlying()).safeTransfer(vault(), balance);
    }
  }

  function withdrawToVault(uint256 amountUnderlying) external restricted {
    // this is similarly gas-efficient as making the calculation for exact xsushi to withdraw
    unwrap();
    require(IERC20(underlying()).balanceOf(address(this)) >= amountUnderlying, "insufficient balance for the withdrawal");
    IERC20(underlying()).safeTransfer(vault(), amountUnderlying);
    wrap();
  }

  function salvage(address recipient, address token, uint256 amount) public onlyGovernance {
    // To make sure that governance cannot come in and take away the coins
    require(!unsalvagableTokens(token), "token is defined as not salvageable");
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
    uint256 axSushi = IERC20(aTokenAddress()).balanceOf(address(this));
    uint256 share = IERC20(xsushi()).balanceOf(address(this)).add(axSushi);
    uint256 totalShares = IERC20(xsushi()).totalSupply();
    uint256 sushiBalance = IERC20(underlying()).balanceOf(address(this));
    return (share.mul(IERC20(underlying()).balanceOf(xsushi())).div(totalShares)).add(sushiBalance);
  }
}
