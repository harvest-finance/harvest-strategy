pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./inheritance/Controllable.sol";
import "./interface/IStrategy.sol";
import "./interface/IVault.sol";
import "./PotPool.sol";

/*
  Simply invests underlying into another vault (the investment vault)
*/
contract InvestmentVaultStrategy is IStrategy, Controllable {

  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  bool public depositArbCheck = true;

  address public underlying;
  address public vault;
  address public investmentVault;
  address public potPool;
  mapping(address => bool) public unsalvagableTokens;

  bool public hodlApproved = true;

  modifier restricted() {
    require(msg.sender == vault || msg.sender == address(controller()) || msg.sender == address(governance()),
      "The sender has to be the controller or vault or governance");
    _;
  }

  constructor(
    address _storage,
    address _vault,
    address _potPool
  ) Controllable(_storage) public {
    // _vault's underlying is not checked because it is mismatching before migration
    vault = _vault;
    potPool = _potPool;
    investmentVault = PotPool(potPool).lpToken();
    underlying = IVault(investmentVault).underlying();
    unsalvagableTokens[underlying] = true;
    unsalvagableTokens[investmentVault] = true;
    unsalvagableTokens[potPool] = true;
  }

  function withdrawAllToVault() public restricted {
    uint256 potPoolBalance = PotPool(potPool).balanceOf(address(this));
    if(potPoolBalance > 0){
      PotPool(potPool).exit();
    }

    uint256 vaultBalance = IVault(investmentVault).balanceOf(address(this));
    if (vaultBalance > 0) {
      IVault(investmentVault).withdraw(vaultBalance);
    }

    uint256 underlyingBalance = IERC20(underlying).balanceOf(address(this));
    if (underlyingBalance > 0) {
      IERC20(underlying).safeTransfer(vault, underlyingBalance);
    }
  }

  function withdrawToVault(uint256 amountUnderlying) external restricted {
    withdrawAllToVault();
    require(IERC20(underlying).balanceOf(address(this)) >= amountUnderlying, "insufficient balance for the withdrawal");
    IERC20(underlying).safeTransfer(vault, amountUnderlying);
    investAllUnderlying();
  }

  function salvage(address recipient, address token, uint256 amount) public onlyGovernance {
    // To make sure that governance cannot come in and take away the coins
    require(!unsalvagableTokens[token], "token is defined as not salvageable");
    IERC20(token).safeTransfer(recipient, amount);
  }

  function doHardWork() public restricted {
    investAllUnderlying();
  }

  function investAllUnderlying() public restricted {
    uint256 underlyingBalance = IERC20(underlying).balanceOf(address(this));
    if (underlyingBalance > 0) {
      IERC20(underlying).safeApprove(investmentVault, 0);
      IERC20(underlying).safeApprove(investmentVault, underlyingBalance);
      IVault(investmentVault).deposit(underlyingBalance);
    }

    uint256 fVaultBalance = IERC20(investmentVault).balanceOf(address(this));
    if(fVaultBalance > 0) {
      IERC20(investmentVault).safeApprove(potPool, 0);
      IERC20(investmentVault).safeApprove(potPool, fVaultBalance);
      PotPool(potPool).stake(fVaultBalance);
    }
  }

  // allows vault to withdraw the reward tokens at any point
  function _claimAndApprove() internal {
    PotPool(potPool).getAllRewards();
    for(uint256 i = 0 ; i < rewardTokensLength(); i = i.add(1)) {
      address rt = PotPool(potPool).rewardTokens(i);
      uint256 rtBalance = IERC20(rt).balanceOf(address(this));
      if( rtBalance > 0 ) {
        IERC20(rt).safeApprove(vault, 0);
        IERC20(rt).safeApprove(vault, rtBalance);
      }
    }
  }

  function getAllRewards() public restricted {
    _claimAndApprove();
  }

  function investedUnderlyingBalance() external view returns (uint256) {
    return IVault(investmentVault).balanceOf(address(this))
      .add(PotPool(potPool).balanceOf(address(this)))
      .mul(IVault(investmentVault).getPricePerFullShare())
      .div(10 ** uint256(ERC20Detailed(address(underlying)).decimals()))
      .add(IERC20(underlying).balanceOf(address(this)));
  }

  function rewardTokensLength() public view returns (uint256) {
    return PotPool(potPool).rewardTokensLength();
  }

  function rewardTokens(uint256 i) public view returns(address){
    return PotPool(potPool).rewardTokens(i);
  }
}
