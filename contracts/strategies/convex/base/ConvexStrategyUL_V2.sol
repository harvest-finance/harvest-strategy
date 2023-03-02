pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../base/interface/IStrategy.sol";
import "../../../base/upgradability/BaseUpgradeableStrategyUL.sol";
import "../interface/IBooster.sol";
import "../interface/IBaseRewardPool.sol";
import "../../../base/interface/curve/ICurveDeposit_2token.sol";
import "../../../base/interface/curve/ICurveDeposit_3token.sol";
import "../../../base/interface/curve/ICurveDeposit_3token_meta.sol";
import "../../../base/interface/curve/ICurveDeposit_4token.sol";
import "../../../base/interface/curve/ICurveDeposit_4token_meta.sol";
import "../../../base/interface/weth/Weth9.sol";

contract ConvexStrategyUL_V2 is IStrategy, BaseUpgradeableStrategyUL {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public constant booster = address(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant multiSigAddr = address(0xF49440C1F012d041802b25A73e5B0B9166a75c02);

  // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
  bytes32 internal constant _POOLID_SLOT = 0x3fd729bfa2e28b7806b03a6e014729f59477b530f995be4d51defc9dad94810b;
  bytes32 internal constant _DEPOSIT_TOKEN_SLOT = 0x219270253dbc530471c88a9e7c321b36afda219583431e7b6c386d2d46e70c86;
  bytes32 internal constant _DEPOSIT_ARRAY_POSITION_SLOT = 0xb7c50ef998211fff3420379d0bf5b8dfb0cee909d1b7d9e517f311c104675b09;
  bytes32 internal constant _CURVE_DEPOSIT_SLOT = 0xb306bb7adebd5a22f5e4cdf1efa00bc5f62d4f5554ef9d62c1b16327cd3ab5f9;
  bytes32 internal constant _HODL_RATIO_SLOT = 0xb487e573671f10704ed229d25cf38dda6d287a35872859d096c0395110a0adb1;
  bytes32 internal constant _HODL_VAULT_SLOT = 0xc26d330f887c749cb38ae7c37873ff08ac4bba7aec9113c82d48a0cf6cc145f2;
  bytes32 internal constant _NTOKENS_SLOT = 0xbb60b35bae256d3c1378ff05e8d7bee588cd800739c720a107471dfa218f74c1;
  bytes32 internal constant _METAPOOL_SLOT = 0x567ad8b67c826974a167f1a361acbef5639a3e7e02e99edbc648a84b0923d5b7;

  uint256 public constant hodlRatioBase = 10000;
  address[] public rewardTokens;

  constructor() public BaseUpgradeableStrategyUL() {
    assert(_POOLID_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.poolId")) - 1));
    assert(_DEPOSIT_TOKEN_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositToken")) - 1));
    assert(_DEPOSIT_ARRAY_POSITION_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositArrayPosition")) - 1));
    assert(_CURVE_DEPOSIT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.curveDeposit")) - 1));
    assert(_HODL_RATIO_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.hodlRatio")) - 1));
    assert(_HODL_VAULT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.hodlVault")) - 1));
    assert(_NTOKENS_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.nTokens")) - 1));
    assert(_METAPOOL_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.metaPool")) - 1));
  }

  function initializeBaseStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    uint256 _poolID,
    address _depositToken,
    uint256 _depositArrayPosition,
    address _curveDeposit,
    uint256 _nTokens,
    bool _metaPool,
    uint256 _hodlRatio
  ) public initializer {

    // calculate profit sharing fee depending on hodlRatio
    uint256 profitSharingNumerator = 150;
    if (_hodlRatio >= 1500) {
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
      weth,
      profitSharingNumerator,  // profit sharing numerator
      1000, // profit sharing denominator
      true, // sell
      0, // sell floor
      12 hours, // implementation change delay
      address(0x7882172921E99d590E097cD600554339fBDBc480) //UL Registry
    );

    address _lpt;
    (_lpt,,,,,) = IBooster(booster).poolInfo(_poolID);
    require(_lpt == underlying(), "Pool Info does not match underlying");
    require(_depositArrayPosition < _nTokens, "Deposit array position out of bounds");
    require(1 < _nTokens && _nTokens < 5, "_nTokens should be 2, 3 or 4");
    _setDepositArrayPosition(_depositArrayPosition);
    _setPoolId(_poolID);
    _setDepositToken(_depositToken);
    _setCurveDeposit(_curveDeposit);
    _setNTokens(_nTokens);
    _setMetaPool(_metaPool);
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
          IBaseRewardPool(rewardPool()).withdrawAllAndUnwrap(true);
      }
  }

  function partialWithdrawalRewardPool(uint256 amount) internal {
    IBaseRewardPool(rewardPool()).withdrawAndUnwrap(amount, false);  //don't claim rewards at this point
  }

  function emergencyExitRewardPool() internal {
    uint256 stakedBalance = rewardPoolBalance();
    if (stakedBalance != 0) {
        IBaseRewardPool(rewardPool()).withdrawAllAndUnwrap(false); //don't claim rewards
    }
  }

  function unsalvagableTokens(address token) public view returns (bool) {
    return (token == rewardToken() || token == underlying());
  }

  function enterRewardPool() internal {
    address _underlying = underlying();
    uint256 entireBalance = IERC20(_underlying).balanceOf(address(this));
    IERC20(_underlying).safeApprove(booster, 0);
    IERC20(_underlying).safeApprove(booster, entireBalance);
    IBooster(booster).depositAll(poolId(), true); //deposit and stake
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

  function addRewardToken(address _token, address[] memory _path, bytes32[] memory _dexes) public onlyGovernance {
    require(_path[_path.length-1] == weth, "Path should end with WETH");
    require(_path[0] == _token, "Path should start with rewardToken");
    require(_dexes.length == _path.length-1, "Inconsistent length for path/dexes");
    rewardTokens.push(_token);
    storedLiquidationPaths[_token][weth] = _path;
    storedLiquidationDexes[_token][weth] = _dexes;
  }

  // We assume that all the tradings can be done on Sushiswap
  function _liquidateReward() internal {
    if (!sell()) {
      // Profits can be disabled for possible simplified and rapoolId exit
      emit ProfitsNotCollected(sell(), false);
      return;
    }

    address _rewardToken = rewardToken();
    address _universalLiquidator = universalLiquidator();
    address _depositToken = depositToken();

    for(uint256 i = 0; i < rewardTokens.length; i++){
      address token = rewardTokens[i];
      uint256 rewardBalance = IERC20(token).balanceOf(address(this));

      // if the token is the rewardToken then there won't be a path defined because liquidation is not necessary,
      // but we still have to make sure that the toHodl part is executed.
      if (rewardBalance == 0 || (storedLiquidationDexes[token][_rewardToken].length < 1) && token != rewardToken()) {
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

      if(token == _rewardToken) {
        // one of the reward tokens is the same as the token that we liquidate to ->
        // no liquidation necessary
        continue;
      }

      IERC20(token).safeApprove(_universalLiquidator, 0);
      IERC20(token).safeApprove(_universalLiquidator, rewardBalance);
      // we can accept 1 as the minimum because this will be called only by a trusted worker
      ILiquidator(_universalLiquidator).swapTokenOnMultipleDEXes(
        rewardBalance,
        1,
        address(this), // target
        storedLiquidationDexes[token][_rewardToken],
        storedLiquidationPaths[token][_rewardToken]
      );
    }

    uint256 rewardBalance = IERC20(_rewardToken).balanceOf(address(this));
    notifyProfitInRewardToken(rewardBalance);
    uint256 remainingRewardBalance = IERC20(_rewardToken).balanceOf(address(this));

    if (remainingRewardBalance == 0) {
      return;
    }

    if(_depositToken != _rewardToken) {
      IERC20(_rewardToken).safeApprove(_universalLiquidator, 0);
      IERC20(_rewardToken).safeApprove(_universalLiquidator, remainingRewardBalance);

      // we can accept 1 as minimum because this is called only by a trusted role
      ILiquidator(_universalLiquidator).swapTokenOnMultipleDEXes(
        remainingRewardBalance,
        1,
        address(this), // target
        storedLiquidationDexes[_rewardToken][_depositToken],
        storedLiquidationPaths[_rewardToken][_depositToken]
      );
    }

    uint256 tokenBalance = IERC20(_depositToken).balanceOf(address(this));
    if (tokenBalance > 0) {
      depositCurve();
    }
  }

  function depositCurve() internal {
    address _depositToken = depositToken();
    address _curveDeposit = curveDeposit();

    uint256 tokenBalance = IERC20(_depositToken).balanceOf(address(this));
    if (_depositToken != weth) {
      IERC20(_depositToken).safeApprove(_curveDeposit, 0);
      IERC20(_depositToken).safeApprove(_curveDeposit, tokenBalance);
    }

    // we can accept 0 as minimum, this will be called only by trusted roles
    uint256 minimum = 0;
    if (nTokens() == 2) {
      uint256[2] memory depositArray;
      depositArray[depositArrayPosition()] = tokenBalance;
      if (_depositToken == weth){
        WETH9(weth).withdraw(tokenBalance);
        ICurveDeposit_2token(_curveDeposit).add_liquidity.value(tokenBalance)(depositArray, minimum);
      } else {
        ICurveDeposit_2token(_curveDeposit).add_liquidity(depositArray, minimum);
      }
    } else if (nTokens() == 3) {
      uint256[3] memory depositArray;
      depositArray[depositArrayPosition()] = tokenBalance;
      if (metaPool()) {
        ICurveDeposit_3token_meta(_curveDeposit).add_liquidity(underlying(), depositArray, minimum);
      } else {
        ICurveDeposit_3token(_curveDeposit).add_liquidity(depositArray, minimum);
      }
    } else if (nTokens() == 4) {
      uint256[4] memory depositArray;
      depositArray[depositArrayPosition()] = tokenBalance;
      if (metaPool()) {
        ICurveDeposit_4token_meta(_curveDeposit).add_liquidity(underlying(), depositArray, minimum);
      } else {
        ICurveDeposit_4token(_curveDeposit).add_liquidity(depositArray, minimum);
      }
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
    address _underlying = underlying();
    if (address(rewardPool()) != address(0)) {
      exitRewardPool();
    }
    _liquidateReward();
    IERC20(_underlying).safeTransfer(vault(), IERC20(_underlying).balanceOf(address(this)));
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawToVault(uint256 amount) public restricted {
    address _underlying = underlying();
    // Typically there wouldn't be any amount here
    // however, it is possible because of the emergencyExit
    uint256 entireBalance = IERC20(_underlying).balanceOf(address(this));

    if(amount > entireBalance){
      // While we have the check above, we still using SafeMath below
      // for the peace of mind (in case something gets changed in between)
      uint256 needToWithdraw = amount.sub(entireBalance);
      uint256 toWithdraw = Math.min(rewardPoolBalance(), needToWithdraw);
      partialWithdrawalRewardPool(toWithdraw);
    }
    IERC20(_underlying).safeTransfer(vault(), amount);
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

  /**
  * Sets the minimum amount of CRV needed to trigger a sale.
  */
  function setSellFloor(uint256 floor) public onlyGovernance {
    _setSellFloor(floor);
  }

  // masterchef rewards pool ID
  function _setPoolId(uint256 _value) internal {
    setUint256(_POOLID_SLOT, _value);
  }

  function poolId() public view returns (uint256) {
    return getUint256(_POOLID_SLOT);
  }

  function _setDepositToken(address _address) internal {
    setAddress(_DEPOSIT_TOKEN_SLOT, _address);
  }

  function depositToken() public view returns (address) {
    return getAddress(_DEPOSIT_TOKEN_SLOT);
  }

  function _setDepositArrayPosition(uint256 _value) internal {
    setUint256(_DEPOSIT_ARRAY_POSITION_SLOT, _value);
  }

  function depositArrayPosition() public view returns (uint256) {
    return getUint256(_DEPOSIT_ARRAY_POSITION_SLOT);
  }

  function _setCurveDeposit(address _address) internal {
    setAddress(_CURVE_DEPOSIT_SLOT, _address);
  }

  function curveDeposit() public view returns (address) {
    return getAddress(_CURVE_DEPOSIT_SLOT);
  }

  function _setNTokens(uint256 _value) internal {
    setUint256(_NTOKENS_SLOT, _value);
  }

  function nTokens() public view returns (uint256) {
    return getUint256(_NTOKENS_SLOT);
  }

  function _setMetaPool(bool _value) internal {
    setBoolean(_METAPOOL_SLOT, _value);
  }

  function metaPool() public view returns (bool) {
    return getBoolean(_METAPOOL_SLOT);
  }


  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
    setHodlVault(multiSigAddr);
    setHodlRatio(1000); // 10%
  }

  function () external payable {} // this is needed for the WETH unwrapping
}
