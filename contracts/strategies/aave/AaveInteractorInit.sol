pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "./interface/ILendingPool.sol";
import "./interface/ILendingPoolAddressesProvider.sol";
import "./interface/IAaveProtocolDataProvider.sol";

contract AaveInteractorInit is Initializable {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  bytes32 internal constant _AAVE_UNDERLYING_SLOT = 0xf84ef7729628122ca33db47d58190140a6c7bd099adee2733cb18ff7e845a056;
  bytes32 internal constant _A_TOKEN_ADDRESS_SLOT = 0x9002ea3817e190ead1c1611e1af7f0342b23e4f547aae36df43f9832921befa3;
  bytes32 internal constant _LENDING_POOL_PROVIDER_SLOT = 0x0df3ecbeae4dcb3be9657d4c0aa360d493a956e4fdcc6f1a28b9290eed644efb;
  bytes32 internal constant _PROTOCOL_DATA_PROVIDER_SLOT = 0xd81bb2d702e605477e8373b22f131ee9512514c5595fb93b099ee74ca2fa6104;

  constructor() public {
    require(_AAVE_UNDERLYING_SLOT == bytes32(uint256(keccak256("eip1967.aaveInteractorInit.aaveUnderlying")) - 1));
    require(_A_TOKEN_ADDRESS_SLOT == bytes32(uint256(keccak256("eip1967.aaveInteractorInit.aTokenAddress")) - 1));
    require(_LENDING_POOL_PROVIDER_SLOT == bytes32(uint256(keccak256("eip1967.aaveInteractorInit.lendingPoolProvider")) - 1));
    require(_PROTOCOL_DATA_PROVIDER_SLOT == bytes32(uint256(keccak256("eip1967.aaveInteractorInit.protocolDataProvider")) - 1));
  }

  function initialize(
    address _underlying,
    address _lendingPoolProvider,
    address _protocolDataProvider
  ) public initializer {
    setAddress(_AAVE_UNDERLYING_SLOT, _underlying);
    setAddress(_LENDING_POOL_PROVIDER_SLOT, _lendingPoolProvider);
    setAddress(_PROTOCOL_DATA_PROVIDER_SLOT, _protocolDataProvider);
    setAddress(_A_TOKEN_ADDRESS_SLOT, aToken());
  }

  function lendingPool() public view returns (address) {
    return ILendingPoolAddressesProvider(lendingPoolProvider()).getLendingPool();
  }

  function aToken() public view returns (address) {
    (address newATokenAddress,,) =
      IAaveProtocolDataProvider(protocolDataProvider()).getReserveTokensAddresses(aaveUnderlying());
    return newATokenAddress;
  }

  function _aaveDeposit(uint256 amount) internal {
    address lendPool = lendingPool();
    IERC20(aaveUnderlying()).safeApprove(lendPool, 0);
    IERC20(aaveUnderlying()).safeApprove(lendPool, amount);

    ILendingPool(lendPool).deposit(
      aaveUnderlying(),
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
    IERC20(aTokenAddress()).safeApprove(lendPool, 0);
    IERC20(aTokenAddress()).safeApprove(lendPool, amount);
    uint256 maxAmount = IERC20(aTokenAddress()).balanceOf(address(this));

    uint256 amountWithdrawn = ILendingPool(lendPool).withdraw(
      aaveUnderlying(),
      amount,
      address(this)
    );

    require(
      amountWithdrawn == amount ||
      (amount == uint256(-1) && maxAmount == IERC20(aaveUnderlying()).balanceOf(address(this))),
      "Did not withdraw requested amount"
    );
  }

  function aaveUnderlying() public view returns(address) {
    return getAddress(_AAVE_UNDERLYING_SLOT);
  }

  function aTokenAddress() public view returns(address) {
    return getAddress(_A_TOKEN_ADDRESS_SLOT);
  }

  function lendingPoolProvider() public view returns(address) {
    return getAddress(_LENDING_POOL_PROVIDER_SLOT);
  }

  function protocolDataProvider() public view returns(address) {
    return getAddress(_PROTOCOL_DATA_PROVIDER_SLOT);
  }

  function setAddress(bytes32 slot, address _address) internal {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      sstore(slot, _address)
    }
  }

  function getAddress(bytes32 slot) internal view returns (address str) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      str := sload(slot)
    }
  }
}
