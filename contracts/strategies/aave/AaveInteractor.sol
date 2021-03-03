pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interface/ILendingPool.sol";
import "./interface/ILendingPoolAddressesProvider.sol";
import "./interface/IAaveProtocolDataProvider.sol";
import "hardhat/console.sol";

contract AaveInteractor {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public aaveUnderlying;
  address public aTokenAddress;

  address public lendingPoolProvider;
  address public protocolDataProvider;

  constructor(
    address _underlying,
    address _lendingPoolProvider,
    address _protocolDataProvider
  ) public {
    aaveUnderlying = _underlying;
    lendingPoolProvider = _lendingPoolProvider;
    protocolDataProvider = _protocolDataProvider;
    aTokenAddress = aToken();
  }

  function lendingPool() public view returns (address) {
    return ILendingPoolAddressesProvider(lendingPoolProvider).getLendingPool();
  }

  function aToken() public view returns (address) {
    (address newATokenAddress,,) =
      IAaveProtocolDataProvider(protocolDataProvider).getReserveTokensAddresses(aaveUnderlying);
    return newATokenAddress;
  }

  function _aaveDeposit(uint256 amount) internal {
    address lendPool = lendingPool();
    IERC20(aaveUnderlying).safeApprove(lendPool, 0);
    IERC20(aaveUnderlying).safeApprove(lendPool, amount);

    ILendingPool(lendPool).deposit(
      aaveUnderlying,
      amount,
      address(this),
      0 // referral code
    );
  }

  function _aaveWithdrawAll() internal {
    _aaveWithdraw(uint256(-1));
  }

  function _aaveWithdraw(uint256 amount) internal {
    address lendPool = lendingPool();
    IERC20(aTokenAddress).safeApprove(lendPool, 0);
    IERC20(aTokenAddress).safeApprove(lendPool, amount);
    uint256 maxAmount = IERC20(aTokenAddress).balanceOf(address(this));

    uint256 amountWithdrawn = ILendingPool(lendPool).withdraw(
      aaveUnderlying,
      amount,
      address(this)
    );

    require(
      amountWithdrawn == amount ||
      (amount == uint256(-1) && maxAmount == IERC20(aaveUnderlying).balanceOf(address(this))),
      "Did not withdraw requested amount"
    );
  }

}
