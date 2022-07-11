pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../base/interface/IStrategy.sol";
import "../../../base/interface/IVault.sol";
import "../../../base/upgradability/BaseUpgradeableStrategyUL.sol";
import "../interface/IBooster.sol";
import "../interface/IBaseRewardPool.sol";
import "../interface/ICrvDeposit.sol";
import "../../../base/interface/curve/ICurveDeposit_2token.sol";
import "../../../base/interface/curve/ICurveDeposit_3token.sol";

contract ConvexStrategyCvxCRV is IStrategy, BaseUpgradeableStrategyUL {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public constant crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
  address public constant threeCrvToken = address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
  address public constant threeCrvPool = address(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
  address public constant dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address public constant multiSigAddr = address(0xF49440C1F012d041802b25A73e5B0B9166a75c02);

  // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
  bytes32 internal constant _CRV_DEPOSIT_SLOT = 0xa51d8d33c6ea269ba2e5cdf18fbb6f730ec80b8144efad972bc86484977c5eed;
  bytes32 internal constant _CVXCRV_SWAP_SLOT = 0xd87cd2673c26d86258018b380e2a81ccb481935d8911a38fbf5a8c4856a76092;
  bytes32 internal constant _HODL_RATIO_SLOT = 0xb487e573671f10704ed229d25cf38dda6d287a35872859d096c0395110a0adb1;
  bytes32 internal constant _HODL_VAULT_SLOT = 0xc26d330f887c749cb38ae7c37873ff08ac4bba7aec9113c82d48a0cf6cc145f2;

  uint256 public constant hodlRatioBase = 10000;
  address[] public rewardTokens;

  constructor() public BaseUpgradeableStrategyUL() {
    assert(_CRV_DEPOSIT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.crvDeposit")) - 1));
    assert(_CVXCRV_SWAP_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.cvxCrvSwap")) - 1));
    assert(_HODL_RATIO_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.hodlRatio")) - 1));
    assert(_HODL_VAULT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.hodlVault")) - 1));
  }

  function initializeBaseStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    address _crvDeposit,
    address _cvxCrvSwap,
    uint256 _hodlRatio
  ) public initializer {

    // calculate profit sharing fee depending on hodlRatio
    uint256 profitSharingNumerator = 300;
    if (_hodlRatio >= 3000) {
      profitSharingNumerator = 0;
    } else if (_hodlRatio > 0){
      // (profitSharingNumerator - hodlRatio/10) * hodlRatioBase / (hodlRatioBase - hodlRatio)
      // e.g. with default values: (300 - 1000 / 10) * 10000 / (10000 - 1000)
      // = (300 - 100) * 10000 / 9000 = 222
      profitSharingNumerator = profitSharingNumerator.sub(_hodlRatio.div(10)) // subtract hodl ratio from profit sharing numerator
                                    .mul(hodlRatioBase) // multiply with hodlRatioBase
                                    .div(hodlRatioBase.sub(_hodlRatio)); // divide by hodlRatioBase minus hodlRatio
    }

    BaseUpgradeableStrategyUL.initialize(
      _storage,
      _underlying,
      _vault,
      _rewardPool,
      crv,
      profitSharingNumerator,  // profit sharing numerator
      1000, // profit sharing denominator
      true, // sell
      0, // sell floor
      12 hours, // implementation change delay
      address(0x7882172921E99d590E097cD600554339fBDBc480) //UL Registry
    );

    address _lpt = IBaseRewardPool(_rewardPool).stakingToken();
    require(_lpt == underlying(), "Pool Info does not match underlying");
    _setCrvDeposit(_crvDeposit);
    _setCvxCrvSwap(_cvxCrvSwap);
    setUint256(_HODL_RATIO_SLOT, _hodlRatio);
    setAddress(_HODL_VAULT_SLOT, multiSigAddr);
    rewardTokens = new address[](0);
  }

  function setHodlRatio(uint256 _value) public onlyGovernance {
    uint256 profitSharingNumerator = 300;
    if (_value >= 3000) {
      profitSharingNumerator = 0;
    } else if (_value > 0){
      // (profitSharingNumerator - hodlRatio/10) * hodlRatioBase / (hodlRatioBase - hodlRatio)
      // e.g. with default values: (300 - 1000 / 10) * 10000 / (10000 - 1000)
      // = (300 - 100) * 10000 / 9000 = 222
      profitSharingNumerator = profitSharingNumerator.sub(_value.div(10)) // subtract hodl ratio from profit sharing numerator
                                    .mul(hodlRatioBase) // multiply with hodlRatioBase
                                    .div(hodlRatioBase.sub(_value)); // divide by hodlRatioBase minus hodlRatio
    }
    _setProfitSharingNumerator(profitSharingNumerator);
    setUint256(_HODL_RATIO_SLOT, _value);
  }

  function hodlRatio() public view returns (uint256) {
    return getUint256(_HODL_RATIO_SLOT);
  }

  function setHodlVault(address _address) public onlyGovernance {
    setAddress(_HODL_VAULT_SLOT, _address);
  }

  function hodlVault() public view returns (address) {
    return getAddress(_HODL_VAULT_SLOT);
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  function rewardPoolBalance() internal view returns (uint256 bal) {
      bal = IBaseRewardPool(rewardPool()).balanceOf(address(this));
  }

  function exitRewardPool() internal {
      uint256 stakedBalance = rewardPoolBalance();
      if (stakedBalance != 0) {
          IBaseRewardPool(rewardPool()).withdrawAll(true);
      }
  }

  function partialWithdrawalRewardPool(uint256 amount) internal {
    IBaseRewardPool(rewardPool()).withdraw(amount, false);  //don't claim rewards at this point
  }

  function emergencyExitRewardPool() internal {
    uint256 stakedBalance = rewardPoolBalance();
    if (stakedBalance != 0) {
        IBaseRewardPool(rewardPool()).withdrawAll(false); //don't claim rewards
    }
  }

  function unsalvagableTokens(address token) public view returns (bool) {
    return (token == rewardToken() || token == underlying());
  }

  function enterRewardPool() internal {
    uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));
    IERC20(underlying()).safeApprove(rewardPool(), 0);
    IERC20(underlying()).safeApprove(rewardPool(), entireBalance);
    IBaseRewardPool(rewardPool()).stakeAll();
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

  function addRewardToken(address _token) public onlyGovernance {
    rewardTokens.push(_token);
  }

  function _liquidateReward() internal {
    if (!sell()) {
      // Profits can be disabled for possible simplified and rapoolId exit
      emit ProfitsNotCollected(sell(), false);
      return;
    }

    for(uint256 i = 0; i < rewardTokens.length; i++){
      address token = rewardTokens[i];
      uint256 rewardBalance = IERC20(token).balanceOf(address(this));
      if (rewardBalance == 0) {
        continue;
      }

      uint256 toHodl = rewardBalance.mul(hodlRatio()).div(hodlRatioBase);
      if (toHodl > 0) {
        IERC20(token).safeTransfer(hodlVault(), toHodl);
        rewardBalance = rewardBalance.sub(toHodl);
        if (rewardBalance == 0) {
          continue;
        }
      }

      if(token == rewardToken()) {
        // one of the reward tokens is the same as the token that we liquidate to ->
        // no liquidation necessary
        continue;
      } else if (token == threeCrvToken) {
        _liquidate3crv();
        continue;
      } else if (storedLiquidationDexes[token][rewardToken()].length < 1) {
        continue;
      }

      IERC20(token).safeApprove(universalLiquidator(), 0);
      IERC20(token).safeApprove(universalLiquidator(), rewardBalance);
      // we can accept 1 as the minimum because this will be called only by a trusted worker
      ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
        rewardBalance,
        1,
        address(this), // target
        storedLiquidationDexes[token][rewardToken()],
        storedLiquidationPaths[token][rewardToken()]
      );
    }

    uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    notifyProfitInRewardToken(rewardBalance);
    uint256 remainingRewardBalance = IERC20(rewardToken()).balanceOf(address(this));

    if (remainingRewardBalance == 0) {
      return;
    }

    _convertCrvToCvxCrv();
  }

  function _liquidate3crv() internal {
    uint256 threeCrvBalance = IERC20(threeCrvToken).balanceOf(address(this));
    if (threeCrvBalance < 1e10) {
      return;
    }
    uint256 daiToRemove = ICurveDeposit_3token(threeCrvPool).calc_withdraw_one_coin(threeCrvBalance, 0);

    ICurveDeposit_3token(threeCrvPool).remove_liquidity_imbalance([daiToRemove, 0, 0], threeCrvBalance);
    uint256 daiBalance = IERC20(dai).balanceOf(address(this));

    IERC20(dai).safeApprove(universalLiquidator(), 0);
    IERC20(dai).safeApprove(universalLiquidator(), daiBalance);
    // we can accept 1 as the minimum because this will be called only by a trusted worker
    ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
      daiBalance,
      1,
      address(this), // target
      storedLiquidationDexes[dai][rewardToken()],
      storedLiquidationPaths[dai][rewardToken()]
    );
  }

  function _convertCrvToCvxCrv() internal {
    uint256 crvBalance = IERC20(rewardToken()).balanceOf(address(this));
    uint256 expectedSwapOutput = ICurveDeposit_2token(cvxCrvSwap()).get_dy(0, 1, crvBalance);
    if (expectedSwapOutput > crvBalance){
      IERC20(crv).safeApprove(cvxCrvSwap(), 0);
      IERC20(crv).safeApprove(cvxCrvSwap(), crvBalance);
      ICurveDeposit_2token(cvxCrvSwap()).exchange(0, 1, crvBalance, crvBalance);
    } else {
      IERC20(crv).safeApprove(crvDeposit(), 0);
      IERC20(crv).safeApprove(crvDeposit(), crvBalance);
      ICrvDeposit(crvDeposit()).deposit(crvBalance, true);
    }
  }

  /*
  *   Stakes everything the strategy holds into the reward pool
  */
  function investAllUnderlying() internal onlyNotPausedInvesting {
    // this check is needed, because most of the SNX reward pools will revert if
    // you try to stake(0).
    if(IERC20(underlying()).balanceOf(address(this)) > 0) {
      enterRewardPool();
    }
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawAllToVault() public restricted {
    if (address(rewardPool()) != address(0)) {
      exitRewardPool();
    }
    _liquidateReward();
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
      uint256 toWithdraw = Math.min(rewardPoolBalance(), needToWithdraw);
      partialWithdrawalRewardPool(toWithdraw);
    }
    IERC20(underlying()).safeTransfer(vault(), amount);
  }

  /*
  *   Note that we currently do not have a mechanism here to include the
  *   amount of reward that is accrued.
  */
  function investedUnderlyingBalance() external view returns (uint256) {
    return rewardPoolBalance()
      .add(IERC20(underlying()).balanceOf(address(this)));
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

  /*
  *   Get the reward, sell it in exchange for underlying, invest what you got.
  *   It's not much, but it's honest work.
  *
  *   Note that although `onlyNotPausedInvesting` is not added here,
  *   calling `investAllUnderlying()` affectively blocks the usage of `doHardWork`
  *   when the investing is being paused by governance.
  */
  function doHardWork() external onlyNotPausedInvesting restricted {
    IBaseRewardPool(rewardPool()).getReward();
    _liquidateReward();
    investAllUnderlying();
  }

  /**
  * Can completely disable claiming UNI rewards and selling. Good for emergency withdraw in the
  * simplest possible way.
  */
  function setSell(bool s) public onlyGovernance {
    _setSell(s);
  }

  function _setCrvDeposit(address _address) internal {
    setAddress(_CRV_DEPOSIT_SLOT, _address);
  }

  function crvDeposit() public view returns (address) {
    return getAddress(_CRV_DEPOSIT_SLOT);
  }

  function _setCvxCrvSwap(address _address) internal {
    setAddress(_CVXCRV_SWAP_SLOT, _address);
  }

  function cvxCrvSwap() public view returns (address) {
    return getAddress(_CVXCRV_SWAP_SLOT);
  }

  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
    setHodlVault(multiSigAddr);
    setHodlRatio(1000); // 10%
  }
}
