//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../base/upgradability/BaseUpgradeableStrategyUL.sol";
import "../interface/IAuraBooster.sol";
import "../interface/IAuraBaseRewardPool.sol";
import "../../../base/interface/IStrategy.sol";
import "../../../base/interface/IVault.sol";
import "../../../base/interface/balancer/IBVault.sol";

contract AuraStrategyUL is 
  IStrategy,
  BaseUpgradeableStrategyUL
{

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public constant booster = address(0x7818A1DA7BD1E64c199029E86Ba244a9798eEE10);
  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant multiSigAddr = address(0xF49440C1F012d041802b25A73e5B0B9166a75c02);

  // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
  bytes32 internal constant _AURA_POOLID_SLOT = 0xbc10a276e435b4e9a9e92986f93a224a34b50c1898d7551c38ef30a08efadec4;
  bytes32 internal constant _BALANCER_POOLID_SLOT = 0xbf3f653715dd45c84a3367d2975f271307cb967d6ce603dc4f0def2ad909ca64;
  bytes32 internal constant _DEPOSIT_TOKEN_SLOT = 0x219270253dbc530471c88a9e7c321b36afda219583431e7b6c386d2d46e70c86;
  bytes32 internal constant _DEPOSIT_RECEIPT_SLOT = 0x414478d5ad7f54ead8a3dd018bba4f8d686ba5ab5975cd376e0c98f98fb713c5;
  bytes32 internal constant _DEPOSIT_ARRAY_INDEX_SLOT = 0xf5304231d5b8db321cd2f83be554278488120895d3326b9a012d540d75622ba3;
  bytes32 internal constant _BALANCER_DEPOSIT_SLOT = 0x76b08b2cd56227309b7289db7320e303755217a3f4b847eb8c47e7e8351bdc53;
  bytes32 internal constant _HODL_RATIO_SLOT = 0xb487e573671f10704ed229d25cf38dda6d287a35872859d096c0395110a0adb1;
  bytes32 internal constant _HODL_VAULT_SLOT = 0xc26d330f887c749cb38ae7c37873ff08ac4bba7aec9113c82d48a0cf6cc145f2;
  bytes32 internal constant _NTOKENS_SLOT = 0xbb60b35bae256d3c1378ff05e8d7bee588cd800739c720a107471dfa218f74c1;

  uint256 public constant hodlRatioBase = 10000;
  address[] public poolAssets;
  address[] public rewardTokens;

  constructor() public BaseUpgradeableStrategyUL() {
    assert(_AURA_POOLID_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.auraPoolId")) - 1));
    assert(_BALANCER_POOLID_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.balancerPoolId")) - 1));
    assert(_DEPOSIT_TOKEN_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositToken")) - 1));
    assert(_DEPOSIT_RECEIPT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositReceipt")) - 1));
    assert(_DEPOSIT_ARRAY_INDEX_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositArrayIndex")) - 1));
    assert(_BALANCER_DEPOSIT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.balancerDeposit")) - 1));
    assert(_HODL_RATIO_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.hodlRatio")) - 1));
    assert(_HODL_VAULT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.hodlVault")) - 1));
    assert(_NTOKENS_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.nTokens")) - 1)); 
  }

  function initializeBaseStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    uint256 _auraPoolID,
    bytes32 _balancerPoolID,
    address _depositToken,
    uint256 _depositArrayPosition,
    address _balancerDeposit,
    uint256 _hodlRatio
  ) public initializer {

    // calculate profit sharing fee depending on hodlRatio
    uint256 profitSharingNumerator = 300;
    if (_hodlRatio >= 3000) {
      profitSharingNumerator = 0;
    } 
    else if (_hodlRatio > 0) {
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
    address _depositReceipt;
    (_lpt,_depositReceipt,,,,) = IAuraBooster(booster).poolInfo(_auraPoolID);
    require(_lpt == underlying(), "Pool Info does not match underlying");
    _setNTokens(poolAssets.length);
    _setDepositArrayIndex(_depositArrayPosition);
    _setAuraPoolId(_auraPoolID);
    _setBalancerPoolId(_balancerPoolID);
    _setDepositToken(_depositToken);
    _setDepositReceipt(_depositReceipt);
    _setbalancerDeposit(_balancerDeposit);
    setUint256(_HODL_RATIO_SLOT, 1000);
    setAddress(_HODL_VAULT_SLOT, multiSigAddr);
  }

  //
  // Set Strategy Metadata Functions
  // 

  function setHodlRatio(uint256 _value) 
    public 
    onlyGovernance 
  {
    uint256 profitSharingNumerator = 300;
    if (_value >= 3000) {
      profitSharingNumerator = 0;
    } 
    else if (_value > 0){
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

  function setHodlVault(address _address) 
    public 
    onlyGovernance 
  {
    setAddress(_HODL_VAULT_SLOT, _address);
  }

  /** Resumes the ability to invest into the underlying reward pools
   */
  function continueInvesting() 
    public 
    onlyGovernance
  {
    _setPausedInvesting(false);
  }

  /** Can completely disable claiming UNI rewards and selling. Good for emergency withdraw in the
   *  simplest possible way.
   */
  function setSell(bool s) 
    public 
    onlyGovernance 
  {
    _setSell(s);
  }

  /** Sets the minimum amount of CRV needed to trigger a sale.
   */
  function setSellFloor(uint256 floor) 
    public 
    onlyGovernance 
  {
    _setSellFloor(floor);
  }

  /** Aura deposit pool ID
   */ 
  function _setAuraPoolId(uint256 _value) 
    internal 
  {
    setUint256(_AURA_POOLID_SLOT, _value);
  }

  /** Balancer deposit pool ID
   */
  function _setBalancerPoolId(bytes32 _value) 
    internal 
  {
    setBytes32(_BALANCER_POOLID_SLOT, _value);
  }

  function _setNTokens(uint256 _value) internal {
    setUint256(_NTOKENS_SLOT, _value);
  }

  function _setDepositToken(address _address) 
    internal 
  {
    setAddress(_DEPOSIT_TOKEN_SLOT, _address);
  }

  function _setDepositReceipt(address _address) 
    internal 
  {
    setAddress(_DEPOSIT_RECEIPT_SLOT, _address);
  }

  function _setDepositArrayIndex(uint256 _value) 
    internal 
  {
    require(_value <= nTokens(), "Invalid index");
    setUint256(_DEPOSIT_ARRAY_INDEX_SLOT, _value);
  }

  function _setbalancerDeposit(address _address) 
    internal 
  {
    setAddress(_BALANCER_DEPOSIT_SLOT, _address);
  }

  //
  // Get Strategy Metadata Functions
  //

  function hodlRatio() 
    public 
    view 
    returns (uint256) 
  {
    return getUint256(_HODL_RATIO_SLOT);
  }

  function hodlVault() 
    public 
    view 
    returns (address) 
  {
    return getAddress(_HODL_VAULT_SLOT);
  }

  function depositArbCheck() 
    public 
    view 
    returns(bool) 
  {
    return true;
  }

  function auraPoolId() 
    public 
    view 
    returns (uint256) 
  {
    return getUint256(_AURA_POOLID_SLOT);
  }

  function balancerPoolId() 
    public 
    view 
    returns (bytes32) 
  {
    return getBytes32(_BALANCER_POOLID_SLOT);
  }

  function nTokens() 
    public 
    view 
    returns (uint256) 
  {
    return getUint256(_NTOKENS_SLOT);
  }

  function depositToken() 
    public 
    view 
    returns (address) 
  {
    return getAddress(_DEPOSIT_TOKEN_SLOT);
  }

  function depositReceipt() 
    public 
    view 
    returns (address) 
  {
    return getAddress(_DEPOSIT_RECEIPT_SLOT);
  }

  function depositArrayIndex() 
    public 
    view 
    returns (uint256) 
  {
    return getUint256(_DEPOSIT_ARRAY_INDEX_SLOT);
  }

  function balancerDeposit() 
    public 
    view
    returns (address) 
  {
    return getAddress(_BALANCER_DEPOSIT_SLOT);
  }

  //
  // Get Strategy Information Functions
  //

  /** Note that we currently do not have a mechanism here to include the
   *  amount of reward that is accrued.
   */
  function investedUnderlyingBalance() 
    external 
    view 
    returns (uint256) 
  {
    return _rewardPoolBalance()
      .add(IERC20(depositReceipt()).balanceOf(address(this)))
      .add(IERC20(underlying()).balanceOf(address(this)));
  }

  //
  // Strategy Operation Functions - Reinvest
  //

  /** Get the reward, sell it in exchange for underlying, invest what you got.
   *  It's not much, but it's honest work.
   *
   *  Note that although `onlyNotPausedInvesting` is not added here,
   *  calling `_investAllUnderlying()` affectively blocks the usage of `doHardWork`
   *  when the investing is being paused by governance.
   */
  function doHardWork() 
    external 
    onlyNotPausedInvesting 
    restricted 
  {
    IAuraBaseRewardPool(rewardPool()).getReward();
    _liquidateReward();
    _investAllUnderlying();
  }

  // We assume that all the tradings can be done on Sushiswap
  function _liquidateReward() 
    internal 
  {
    // Profits can be disabled for possible simplified and rapoolId exit
    if (!sell()) {
      emit ProfitsNotCollected(sell(), false);
      return;
    }

    address universalRewardToken = rewardToken();
    address universalDepositToken = depositToken();
    address universalLiquidator = universalLiquidator();
    for(uint256 i = 0; i < rewardTokens.length; i++){
      address token = rewardTokens[i];
      uint256 rewardBalance = IERC20(token).balanceOf(address(this));
      
      // if the token is the rewardToken then there won't be a path defined because liquidation is not necessary,
      // but we still have to make sure that the toHodl part is executed.
      if (rewardBalance == 0 || 
          (storedLiquidationDexes[token][universalRewardToken].length < 1) && 
           token != universalRewardToken) {
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

      if(token == universalRewardToken) {
        // one of the reward tokens is the same as the token that we liquidate to -> 
        // no liquidation necessary
        continue;
      }
      IERC20(token).safeApprove(universalLiquidator, 0);
      IERC20(token).safeApprove(universalLiquidator, rewardBalance);
      // we can accept 1 as the minimum because this will be called only by a trusted worker
      ILiquidator(universalLiquidator).swapTokenOnMultipleDEXes(
        rewardBalance,
        1,
        address(this), // target
        storedLiquidationDexes[token][universalRewardToken],
        storedLiquidationPaths[token][universalRewardToken]
      );
    }

    uint256 rewardBalance = IERC20(universalRewardToken).balanceOf(address(this));
    notifyProfitInRewardToken(rewardBalance);
    uint256 remainingRewardBalance = IERC20(universalRewardToken).balanceOf(address(this));

    if (remainingRewardBalance == 0) {
      return;
    }

    if(universalDepositToken != universalRewardToken) {
      IERC20(universalRewardToken).safeApprove(universalLiquidator, 0);
      IERC20(universalRewardToken).safeApprove(universalLiquidator, remainingRewardBalance);

      // we can accept 1 as minimum because this is called only by a trusted role
      ILiquidator(universalLiquidator).swapTokenOnMultipleDEXes(
        remainingRewardBalance,
        1,
        address(this), // target
        storedLiquidationDexes[universalRewardToken][universalDepositToken],
        storedLiquidationPaths[universalRewardToken][universalDepositToken]
      );
    }

    uint256 tokenBalance = IERC20(universalDepositToken).balanceOf(address(this));
    if (tokenBalance > 0) {
      depositLP();
    }
  }

  function depositLP() 
    internal 
  {
    address universalDepositToken = depositToken();
    uint256 tokenBalance = IERC20(universalDepositToken).balanceOf(address(this));

    IERC20(universalDepositToken).safeApprove(balancerDeposit(), 0);
    IERC20(universalDepositToken).safeApprove(balancerDeposit(), tokenBalance);

    // we can accept 0 as minimum, this will be called only by trusted roles
    
    IAsset[] memory assets = new IAsset[](nTokens());
    for (uint256 i = 0; i < nTokens(); i++) {
      assets[i] = IAsset(poolAssets[i]);
    }

    IBVault.JoinKind joinKind = IBVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT;
    uint256[] memory amountsIn = new uint256[](nTokens());
    amountsIn[depositArrayIndex()] = tokenBalance;
    uint256 minAmountOut = 1;

    bytes memory userData = abi.encode(joinKind, amountsIn, minAmountOut);

    IBVault.JoinPoolRequest memory request;
    request.assets = assets;
    request.maxAmountsIn = amountsIn;
    request.userData = userData;
    request.fromInternalBalance = false;

    IBVault(balancerDeposit()).joinPool(
      balancerPoolId(),
      address(this),
      address(this),
      request
    );
  }

  /**   Stakes everything the strategy holds into the reward pool
   */
  function _investAllUnderlying() 
    internal 
    onlyNotPausedInvesting 
  {
    // this check is needed, because most of the SNX reward pools will revert if
    // you try to stake(0).
    if(IERC20(underlying()).balanceOf(address(this)) > 0) {
      _enterRewardPool();
    }
  }

  function _enterRewardPool() 
    internal 
  {
    address lpToken = underlying();
    uint256 entireBalance = IERC20(lpToken).balanceOf(address(this));
    IERC20(lpToken).safeApprove(booster, 0);
    IERC20(lpToken).safeApprove(booster, entireBalance);
    IAuraBooster(booster).depositAll(auraPoolId(), true); //deposit and stake
  }

  function addRewardToken(address _token) 
    public 
    onlyGovernance 
  {
    rewardTokens.push(_token);
  }

  //
  // Strategy Operation Functions - Exit
  //

  /** Withdraws all the asset to the vault
   */
  function withdrawAllToVault() 
    public 
    restricted 
  {
    address lpToken = underlying();
    if (address(rewardPool()) != address(0)) {
      exitRewardPool();
    }
    _liquidateReward();
    IERC20(lpToken).safeTransfer(vault(), IERC20(lpToken).balanceOf(address(this)));
  }

  /** Withdraws all the asset to the vault
   */
  function withdrawToVault(uint256 amount) 
    public 
    restricted 
  {
    address lpToken = underlying();
    // Typically there wouldn't be any amount here
    // however, it is possible because of the emergencyExit
    uint256 entireBalance = IERC20(lpToken).balanceOf(address(this));

    if(amount > entireBalance){
      // While we have the check above, we still using SafeMath below
      // for the peace of mind (in case something gets changed in between)
      uint256 needToWithdraw = amount.sub(entireBalance);
      uint256 toWithdraw = Math.min(_rewardPoolBalance(), needToWithdraw);
      partialWithdrawalRewardPool(toWithdraw);
    }
    IERC20(lpToken).safeTransfer(vault(), amount);
  }

  function partialWithdrawalRewardPool(uint256 amount) 
    internal 
  {
    IAuraBaseRewardPool(rewardPool()).withdrawAndUnwrap(amount, false);  //don't claim rewards at this point
  }

  /** In case there are some issues discovered about the pool or underlying asset
   *  Governance can exit the pool properly
   *  The function is only used for emergency to exit the pool
   */
  function emergencyExit() 
    public 
    onlyGovernance 
  {
    _emergencyExitRewardPool();
    _setPausedInvesting(true);
  }

  function _emergencyExitRewardPool() 
    internal 
  {
    uint256 stakedBalance = _rewardPoolBalance();
    if (stakedBalance != 0) {
        IAuraBaseRewardPool(rewardPool()).withdrawAllAndUnwrap(false); //don't claim rewards
    }
  }

  function exitRewardPool() 
    internal 
  {
      uint256 stakedBalance = _rewardPoolBalance();
      if (stakedBalance != 0) {
          IAuraBaseRewardPool(rewardPool()).withdrawAllAndUnwrap(true);
      }
  }

  function _rewardPoolBalance() 
    internal 
    view 
    returns (uint256 balance) 
  {
      balance = IAuraBaseRewardPool(rewardPool()).balanceOf(address(this));
  }

  //
  // Strategy Operation Functions - Miscellaneous
  //

  /** Governance or Controller can claim coins that are somehow transferred into the contract
   *  Note that they cannot come in take away coins that are used and defined in the strategy itself
   */
  function salvage(
    address recipient, 
    address token, 
    uint256 amount
  ) 
    external 
    onlyControllerOrGovernance 
  {
     // To make sure that governance cannot come in and take away the coins
    require(!unsalvagableTokens(token), "token is defined as not salvagable");
    IERC20(token).safeTransfer(recipient, amount);
  }

  function unsalvagableTokens(address token) 
    public 
    view 
    returns (bool) 
  {
    return (token == rewardToken() || token == underlying() || token == depositReceipt());
  }

  function finalizeUpgrade() 
    external 
    onlyGovernance 
  {
    _finalizeUpgrade();
    setHodlVault(multiSigAddr);
    setHodlRatio(1000); // 10%
  }
}
