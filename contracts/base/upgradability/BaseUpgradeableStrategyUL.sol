pragma solidity 0.5.16;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "./BaseUpgradeableStrategyStorage.sol";
import "../inheritance/ControllableInit.sol";
import "../interface/IController.sol";
import "../interface/IFeeRewardForwarderV6.sol";
import "../interface/ILiquidator.sol";
import "../interface/ILiquidatorRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract BaseUpgradeableStrategyUL is Initializable, ControllableInit, BaseUpgradeableStrategyStorage {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  bytes32 internal constant _UL_REGISTRY_SLOT = 0x7a4b558e8ed4a66729f4a918db093413f0f1ae77c0de7c88bea8b99e084b2a17;
  bytes32 internal constant _UL_SLOT = 0xebfe408f65547b28326a79acf512c0f9a2bf4211ece39254d7c3ec96dd3dd242;

  mapping(address => mapping(address => address[])) public storedLiquidationPaths;
  mapping(address => mapping(address => bytes32[])) public storedLiquidationDexes;

  event ProfitsNotCollected(bool sell, bool floor);
  event ProfitLogInReward(uint256 profitAmount, uint256 feeAmount, uint256 timestamp);
  event ProfitAndBuybackLog(uint256 profitAmount, uint256 feeAmount, uint256 timestamp);

  modifier restricted() {
    require(msg.sender == vault() || msg.sender == controller()
      || msg.sender == governance(),
      "The sender has to be the controller, governance, or vault");
    _;
  }

  // This is only used in `investAllUnderlying()`
  // The user can still freely withdraw from the strategy
  modifier onlyNotPausedInvesting() {
    require(!pausedInvesting(), "Action blocked as the strategy is in emergency state");
    _;
  }

  constructor() public BaseUpgradeableStrategyStorage() {
    assert(_UL_REGISTRY_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.ULRegistry")) - 1));
    assert(_UL_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.UL")) - 1));
  }

  function initialize(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    address _rewardToken,
    uint256 _profitSharingNumerator,
    uint256 _profitSharingDenominator,
    bool _sell,
    uint256 _sellFloor,
    uint256 _implementationChangeDelay,
    address _universalLiquidatorRegistry
  ) public initializer {
    ControllableInit.initialize(
      _storage
    );
    _setUnderlying(_underlying);
    _setVault(_vault);
    _setRewardPool(_rewardPool);
    _setRewardToken(_rewardToken);
    _setProfitSharingNumerator(_profitSharingNumerator);
    _setProfitSharingDenominator(_profitSharingDenominator);

    _setSell(_sell);
    _setSellFloor(_sellFloor);
    _setNextImplementationDelay(_implementationChangeDelay);
    _setPausedInvesting(false);
    _setUniversalLiquidatorRegistry(_universalLiquidatorRegistry);
    _setUniversalLiquidator(ILiquidatorRegistry(universalLiquidatorRegistry()).universalLiquidator());
  }

  /**
  * Schedules an upgrade for this vault's proxy.
  */
  function scheduleUpgrade(address impl) public onlyGovernance {
    _setNextImplementation(impl);
    _setNextImplementationTimestamp(block.timestamp.add(nextImplementationDelay()));
  }

  function _finalizeUpgrade() internal {
    _setNextImplementation(address(0));
    _setNextImplementationTimestamp(0);
  }

  function shouldUpgrade() external view returns (bool, address) {
    return (
      nextImplementationTimestamp() != 0
        && block.timestamp > nextImplementationTimestamp()
        && nextImplementation() != address(0),
      nextImplementation()
    );
  }

  // reward notification

  function notifyProfitInRewardToken(uint256 _rewardBalance) internal {
    if( _rewardBalance > 0 ){
      uint256 feeAmount = _rewardBalance.mul(profitSharingNumerator()).div(profitSharingDenominator());
      emit ProfitLogInReward(_rewardBalance, feeAmount, block.timestamp);
      IERC20(rewardToken()).safeApprove(controller(), 0);
      IERC20(rewardToken()).safeApprove(controller(), feeAmount);

      IController(controller()).notifyFee(
        rewardToken(),
        feeAmount
      );
    } else {
      emit ProfitLogInReward(0, 0, block.timestamp);
    }
  }

  function notifyProfitAndBuybackInRewardToken(uint256 _rewardBalance, address pool, uint256 _buybackRatio) internal {
    if( _rewardBalance > 0 ){
      uint256 feeAmount = _rewardBalance.mul(profitSharingNumerator()).div(profitSharingDenominator());
      uint256 buybackAmount = _rewardBalance.sub(feeAmount).mul(_buybackRatio).div(10000);

      address forwarder = IController(controller()).feeRewardForwarder();
      emit ProfitAndBuybackLog(_rewardBalance, feeAmount, block.timestamp);

      IERC20(rewardToken()).safeApprove(forwarder, 0);
      IERC20(rewardToken()).safeApprove(forwarder, _rewardBalance);

      IFeeRewardForwarderV6(forwarder).notifyFeeAndBuybackAmounts(
        rewardToken(),
        feeAmount,
        pool,
        buybackAmount
      );
    } else {
      emit ProfitAndBuybackLog(0, 0, block.timestamp);
    }
  }

  function _setUniversalLiquidatorRegistry(address _address) internal {
    setAddress(_UL_REGISTRY_SLOT, _address);
  }

  function universalLiquidatorRegistry() public view returns (address) {
    return getAddress(_UL_REGISTRY_SLOT);
  }

  function _setUniversalLiquidator(address _address) internal {
    setAddress(_UL_SLOT, _address);
  }

  function universalLiquidator() public view returns (address) {
    return getAddress(_UL_SLOT);
  }

  function configureLiquidation(address[] memory path, bytes32[] memory dexes) public onlyGovernance {
    address fromToken = path[0];
    address toToken = path[path.length - 1];

    require(dexes.length == path.length - 1, "lengths do not match");

    storedLiquidationPaths[fromToken][toToken] = path;
    storedLiquidationDexes[fromToken][toToken] = dexes;
  }
}
