pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "../../base/upgradability/BaseUpgradeableStrategy.sol";
import "./interfaces/ILiquidityMining.sol";
import "../../base/interface/uniswap/IUniswapV2Pair.sol";
import "./interfaces/IProxyActions.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IUSDCVault.sol";

import "hardhat/console.sol";

contract ComplifiDerivStrategy is IStrategy, BaseUpgradeableStrategy {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public constant uniswapRouterV2 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public constant usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

  // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
  bytes32 internal constant _POOLID_UNDERLYING_SLOT = 0x2668b27e0735c5f6e35079d508e3204198f7707448f1ebb98fca59c4c52b8f07;
  bytes32 internal constant _POOLID_UP_SLOT = 0x6be613a6d2004c4d2e1084c374896d7fbed4970f361e0e7674fa219f91ad3b15;
  bytes32 internal constant _POOLID_DOWN_SLOT = 0xccb93df1ed8ce69edd49f5292dc925acceb5faa9245e0e03d458acdf91ae0501;
  bytes32 internal constant _USDC_VAULT_SLOT = 0xaab6b4bd3b91f202325685e422df24f288f829eb6e79991474d39f569c7e1da1;
  bytes32 internal constant _PROXY_SLOT = 0xe0898eac8b9a936189ab0c51fb8795de984bdabad6d1a277d006fecbf46049ee;
  bytes32 internal constant _UP_TOKEN_SLOT = 0xe78c0ac41746e02ab5fe2f13a047af360821ac5121402db1b87842b4ca7da4e8;
  bytes32 internal constant _DOWN_TOKEN_SLOT = 0x6601600d2d4d050af79e2b98cf2cb31878b3a629ac3903e218a71e7adc68cf8d;


  // this would be reset on each upgrade
  address[] public liquidationPath;

  constructor() public BaseUpgradeableStrategy() {
    assert(_POOLID_UNDERLYING_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.poolIdUnderlying")) - 1));
    assert(_POOLID_UP_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.poolIdUp")) - 1));
    assert(_POOLID_DOWN_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.poolIdDown")) - 1));
    assert(_USDC_VAULT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.usdcVault")) - 1));
    assert(_PROXY_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.proxy")) - 1));
    assert(_UP_TOKEN_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.upToken")) - 1));
    assert(_DOWN_TOKEN_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.downToken")) - 1));
  }

  function initializeStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    address _rewardToken,
    address _usdcVault,
    address _proxy
  ) public initializer {

    BaseUpgradeableStrategy.initialize(
      _storage,
      _underlying,
      _vault,
      _rewardPool,
      _rewardToken,
      300, // profit sharing numerator
      1000, // profit sharing denominator
      true, // sell
      1e18, // sell floor
      12 hours // implementation change delay
    );

    address _lpt;
    uint256 pidUnderlying = ILiquidityMining(rewardPool()).poolPidByAddress(_underlying);
    (_lpt,,,) = ILiquidityMining(rewardPool()).poolInfo(pidUnderlying);
    require(_lpt == underlying(), "Pool Info does not match underlying");
    address upToken = IUSDCVault(_usdcVault).primaryToken();
    address downToken = IUSDCVault(_usdcVault).complementToken();
    uint256 pidUp = ILiquidityMining(rewardPool()).poolPidByAddress(upToken);
    uint256 pidDown = ILiquidityMining(rewardPool()).poolPidByAddress(downToken);
    _setPoolIdUnderlying(pidUnderlying);
    _setPoolIdUp(pidUp);
    _setPoolIdDown(pidDown);
    _setUSDCVault(_usdcVault);
    _setProxy(_proxy);
    _setUpToken(upToken);
    _setDownToken(downToken);
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  function rewardPoolBalances() internal view returns (uint256 balUnderlying, uint256 balUp, uint256 balDown) {
      (balUnderlying,) = ILiquidityMining(rewardPool()).userPoolInfo(poolIdUnderlying(), address(this));
      (balUp,) = ILiquidityMining(rewardPool()).userPoolInfo(poolIdUp(), address(this));
      (balDown,) = ILiquidityMining(rewardPool()).userPoolInfo(poolIdDown(), address(this));
  }

  function exitRewardPool() internal {
      (uint256 balUnderlying, uint256 balUp, uint256 balDown) = rewardPoolBalances();
      if (balUnderlying != 0) {
          ILiquidityMining(rewardPool()).withdraw(poolIdUnderlying(), balUnderlying);
      }
      if (balUp != 0) {
          ILiquidityMining(rewardPool()).withdraw(poolIdUp(), balUp);
      }
      if (balDown != 0) {
          ILiquidityMining(rewardPool()).withdraw(poolIdDown(), balDown);
      }
  }

  function emergencyExitRewardPool() internal {
    (uint256 balUnderlying, uint256 balUp, uint256 balDown) = rewardPoolBalances();
      if (balUnderlying != 0) {
          ILiquidityMining(rewardPool()).withdrawEmergency(poolIdUnderlying());
      }
      if (balUp != 0) {
          ILiquidityMining(rewardPool()).withdrawEmergency(poolIdUp());
      }
      if (balDown != 0) {
          ILiquidityMining(rewardPool()).withdrawEmergency(poolIdDown());
      }
  }

  function unsalvagableTokens(address token) public view returns (bool) {
    return (token == rewardToken() || token == underlying());
  }

  function enterRewardPool(address _token) internal {
    uint256 entireBalance = IERC20(_token).balanceOf(address(this));
    IERC20(_token).safeApprove(rewardPool(), 0);
    IERC20(_token).safeApprove(rewardPool(), entireBalance);
    ILiquidityMining(rewardPool()).deposit(ILiquidityMining(rewardPool()).poolPidByAddress(_token), entireBalance);
  }

  /*
  *   In case there are some issues discovered about the pool or underlying asset
  *   Governance can exit the pool properly
  *   The function is only used for emergency to exit the pool
  */
  function emergencyExit() public onlyGovernance {
    emergencyExitRewardPool();
    _setPausedInvesting(true);
  }

  /*
  *   Resumes the ability to invest into the underlying reward pools
  */

  function continueInvesting() public onlyGovernance {
    _setPausedInvesting(false);
  }

  function setLiquidationPath(address [] memory _route) public onlyGovernance {
    require(_route[0] == rewardToken(), "Path should start with reward");
    require(_route[_route.length-1] == usdc, "Path should end with USDC");
    liquidationPath = _route;
  }

  // We assume that all the tradings can be done on Uniswap
  function _liquidateReward() internal {
    uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    if (!sell() || rewardBalance < sellFloor()) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected(sell(), rewardBalance < sellFloor());
      return;
    }

    notifyProfitInRewardToken(rewardBalance);
    uint256 remainingRewardBalance = IERC20(rewardToken()).balanceOf(address(this));

    if (remainingRewardBalance == 0) {
      return;
    }

    // allow Uniswap to sell our reward
    IERC20(rewardToken()).safeApprove(uniswapRouterV2, 0);
    IERC20(rewardToken()).safeApprove(uniswapRouterV2, remainingRewardBalance);

    // we can accept 1 as minimum because this is called only by a trusted role
    uint256 amountOutMin = 1;

    IUniswapV2Router02(uniswapRouterV2).swapExactTokensForTokens(
      remainingRewardBalance,
      amountOutMin,
      liquidationPath,
      address(this),
      block.timestamp
    );
  }

  function _usdcToUnderlying() internal {
    uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
    if(usdcBalance == 0) {
      return;
    }
    IERC20(usdc).safeApprove(proxy(), 0);
    IERC20(usdc).safeApprove(proxy(), usdcBalance);

    IProxyActions(proxy()).mintAndJoinPool(underlying(), usdcBalance, address(0), 0, address(0), 0, 0);
    IProxyActions(proxy()).extractChange(underlying());
  }

  /*
  *   Stakes everything the strategy holds into the reward pool
  */
  function investAllUnderlying() internal onlyNotPausedInvesting {
    // this check is needed, because most of the SNX reward pools will revert if
    // you try to stake(0).
    if(IERC20(underlying()).balanceOf(address(this)) > 0) {
      enterRewardPool(underlying());
    }
    if(IERC20(upToken()).balanceOf(address(this)) > 0) {
      enterRewardPool(upToken());
    }
    if(IERC20(downToken()).balanceOf(address(this)) > 0) {
      enterRewardPool(downToken());
    }
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawAllToVault() public restricted {
    if (address(rewardPool()) != address(0)) {
      exitRewardPool();
    }
    ILiquidityMining(rewardPool()).claim();
    _liquidateReward();
    _usdcToUnderlying();
    IERC20(underlying()).safeTransfer(vault(), IERC20(underlying()).balanceOf(address(this)));
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawToVault(uint256 amount) public restricted {
    // Typically there wouldn't be any amount here
    // however, it is possible because of the emergencyExit
    uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));

    if(amount > entireBalance){
      // While we have the check above, we still using SafeMath below
      // for the peace of mind (in case something gets changed in between)
      uint256 needToWithdraw = amount.sub(entireBalance);
      (uint256 rewardPoolBalance,,) = rewardPoolBalances();
      uint256 toWithdraw = Math.min(rewardPoolBalance, needToWithdraw);
      ILiquidityMining(rewardPool()).withdraw(poolIdUnderlying(), toWithdraw);
    }

    IERC20(underlying()).safeTransfer(vault(), amount);
  }

  /*
  *   Note that we currently do not have a mechanism here to include the
  *   amount of reward that is accrued.
  */
  function investedUnderlyingBalance() external view returns (uint256) {
    if (rewardPool() == address(0)) {
      return IERC20(underlying()).balanceOf(address(this));
    }
    // Adding the amount locked in the reward pool and the amount that is somehow in this contract
    // both are in the units of "underlying"
    // The second part is needed because there is the emergency exit mechanism
    // which would break the assumption that all the funds are always inside of the reward pool
    (uint256 rewardPoolBalance,,) = rewardPoolBalances();
    return rewardPoolBalance.add(IERC20(underlying()).balanceOf(address(this)));
  }

  /*
  *   Governance or Controller can claim coins that are somehow transferred into the contract
  *   Note that they cannot come in take away coins that are used and defined in the strategy itself
  */
  function salvage(address recipient, address token, uint256 amount) external onlyControllerOrGovernance {
     // To make sure that governance cannot come in and take away the coins
    require(!unsalvagableTokens(token), "token is defined as not salvagable");
    IERC20(token).safeTransfer(recipient, amount);
  }

  function redeemDerivatives() external onlyGovernance {
    exitRewardPool();
    uint256 balanceUp = IERC20(upToken()).balanceOf(address(this));
    uint256 balanceDown = IERC20(downToken()).balanceOf(address(this));
    uint256[] memory empty;

    IProxyActions(proxy()).redeem(usdcVault(), balanceUp, balanceDown, empty);
  }

  /*
  *   Get the reward, sell it in exchange for underlying, invest what you got.
  *   It's not much, but it's honest work.
  *
  *   Note that although `onlyNotPausedInvesting` is not added here,
  *   calling `investAllUnderlying()` affectively blocks the usage of `doHardWork`
  *   when the investing is being paused by governance.
  */
  function doHardWork() external onlyNotPausedInvesting restricted {
    ILiquidityMining(rewardPool()).claim();
    _liquidateReward();
    _usdcToUnderlying();
    investAllUnderlying();
  }

  /**
  * Can completely disable claiming UNI rewards and selling. Good for emergency withdraw in the
  * simplest possible way.
  */
  function setSell(bool s) public onlyGovernance {
    _setSell(s);
  }

  /**
  * Sets the minimum amount of CRV needed to trigger a sale.
  */
  function setSellFloor(uint256 floor) public onlyGovernance {
    _setSellFloor(floor);
  }

  // masterchef rewards pool ID
  function _setPoolIdUnderlying(uint256 _value) internal {
    setUint256(_POOLID_UNDERLYING_SLOT, _value);
  }

  function poolIdUnderlying() public view returns (uint256) {
    return getUint256(_POOLID_UNDERLYING_SLOT);
  }

  function _setPoolIdUp(uint256 _value) internal {
    setUint256(_POOLID_UP_SLOT, _value);
  }

  function poolIdUp() public view returns (uint256) {
    return getUint256(_POOLID_UP_SLOT);
  }

  function _setPoolIdDown(uint256 _value) internal {
    setUint256(_POOLID_DOWN_SLOT, _value);
  }

  function poolIdDown() public view returns (uint256) {
    return getUint256(_POOLID_DOWN_SLOT);
  }

  function _setUSDCVault(address _address) internal {
    setAddress(_USDC_VAULT_SLOT, _address);
  }

  function usdcVault() public view returns (address) {
    return getAddress(_USDC_VAULT_SLOT);
  }

  function _setProxy(address _address) internal {
    setAddress(_PROXY_SLOT, _address);
  }

  function proxy() public view returns (address) {
    return getAddress(_PROXY_SLOT);
  }

  function _setUpToken(address _address) internal {
    setAddress(_UP_TOKEN_SLOT, _address);
  }

  function upToken() public view returns (address) {
    return getAddress(_UP_TOKEN_SLOT);
  }

  function _setDownToken(address _address) internal {
    setAddress(_DOWN_TOKEN_SLOT, _address);
  }

  function downToken() public view returns (address) {
    return getAddress(_DOWN_TOKEN_SLOT);
  }

  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
    // reset the liquidation paths
    // they need to be re-set manually
  }
}
