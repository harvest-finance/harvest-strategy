pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/IMasterChefV2.sol";
import "../interface/IStrategy.sol";
import "../interface/IVault.sol";
import "../interface/uniswap/IUniswapV2Pair.sol";
import "../interface/uniswap/IUniswapV2Router02.sol";

import "../upgradability/BaseUpgradeableStrategyUL.sol";

contract MasterChefV2StrategyULTwoRewardTokens is
  IStrategy,
  BaseUpgradeableStrategyUL
{
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // additional storage slots (on top of BaseUpgradeableStrategyUL ones) are defined here
  bytes32 internal constant _POOLID_SLOT =
    0x3fd729bfa2e28b7806b03a6e014729f59477b530f995be4d51defc9dad94810b;

  bytes32 internal constant _ROUTERV2_SLOT =
    0x6c5c010713c84cd21d7f2ccc2e0a9f60782ea1e571a64c927352ff8e76aa31ef;

  bytes32 internal constant _SECOND_REWARD_TOKEN_SLOT =
    0xd06e5f1f8ce4bdaf44326772fc9785917d444f120d759a01f1f440e0a42d67a3;

  constructor() public BaseUpgradeableStrategyUL() {
    assert(
      _POOLID_SLOT ==
        bytes32(
          uint256(keccak256("eip1967.strategyStorage.poolId")) - 1
        )
    );

    assert(
      _ROUTERV2_SLOT ==
        bytes32(
          uint256(keccak256("eip1967.strategyStorage.routerV2")) - 1
        )
    );
    assert(
      _SECOND_REWARD_TOKEN_SLOT ==
        bytes32(
          uint256(
            keccak256("eip1967.strategyStorage.secondRewardToken")
          ) - 1
        )
    );
  }

  function initializeBaseStrategy(
    //  "__" for storage because we shadow _storage from GovernableInit
    address __storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    address _rewardToken,
    address _secondRewardToken,
    uint256 _poolID,
    address _routerV2
  ) public initializer {
    address underlying_ = address(
      IMasterChefV2(_rewardPool).lpToken(_poolID)
    );

    require(
      underlying_ == _underlying,
      "Pool Info does not match underlying"
    );

    BaseUpgradeableStrategyUL.initialize({
      _storage: __storage,
      _underlying: _underlying,
      _vault: _vault,
      _rewardPool: _rewardPool,
      _rewardToken: _rewardToken,
      _profitSharingNumerator: 300,
      _profitSharingDenominator: 1000,
      _sell: true,
      _sellFloor: 1e18,
      _implementationChangeDelay: 12 hours,
      _universalLiquidatorRegistry: address(
        0x7882172921E99d590E097cD600554339fBDBc480
      )
    });

    _setPoolId(_poolID);
    _setRouterV2(_routerV2);
    _setSecondRewardToken(_secondRewardToken);
  }

  /*///////////////////////////////////////////////////////////////
      STORAGE SETTER AND GETTER
  //////////////////////////////////////////////////////////////*/

  function _setPoolId(uint256 _value) internal {
    setUint256(_POOLID_SLOT, _value);
  }

  function poolId() public view returns (uint256) {
    return getUint256(_POOLID_SLOT);
  }

  function _setRouterV2(address _router) internal {
    setAddress(_ROUTERV2_SLOT, _router);
  }

  function getRouterV2() public view returns (address) {
    return getAddress(_ROUTERV2_SLOT);
  }

  function _setSecondRewardToken(address _secondRewardToken) internal {
    setAddress(_SECOND_REWARD_TOKEN_SLOT, _secondRewardToken);
  }

  function getSecondRewardToken() public view returns (address) {
    return getAddress(_SECOND_REWARD_TOKEN_SLOT);
  }

  function setSell(bool s) public onlyGovernance {
    _setSell(s);
  }

  function setSellFloor(uint256 floor) public onlyGovernance {
    _setSellFloor(floor);
  }

  /*///////////////////////////////////////////////////////////////
                  PROXY - FINALIZE UPGRADE
  //////////////////////////////////////////////////////////////*/

  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
  }

  /*///////////////////////////////////////////////////////////////
                  INTERNAL HELPER FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function _rewardPoolBalance() internal view returns (uint256 bal) {
    (bal, ) = IMasterChefV2(rewardPool()).userInfo(poolId(), address(this));
  }

  function _exitRewardPool() internal {
    uint256 bal = _rewardPoolBalance();
    if (bal != 0) {
      IMasterChefV2(rewardPool()).withdrawAndHarvest(
        poolId(),
        bal,
        address(this)
      );
    }
  }

  // harvest all the rewards from the MasterV2
  function _harvestPoolRewards() internal {
    IMasterChefV2(rewardPool()).harvest(poolId(), address(this));
  }

  function _emergencyExitRewardPool() internal {
    uint256 bal = _rewardPoolBalance();
    if (bal != 0) {
      IMasterChefV2(rewardPool()).emergencyWithdraw(
        poolId(),
        address(this)
      );
    }
  }

  function _enterRewardPool() internal {
    // cache storage read to underlying() to save GAS
    address underlying_ = underlying();
    // cache storage read to rewardPool() to save GAS,
    // added "_" such that we don't shadow BaseUpgradableStartegyStorage.rewardPool
    address rewardPool_ = rewardPool();

    uint256 entireBalance = IERC20(underlying_).balanceOf(address(this));

    IERC20(underlying_).safeApprove(rewardPool_, 0);
    IERC20(underlying_).safeApprove(rewardPool_, entireBalance);

    IMasterChefV2(rewardPool_).deposit(
      poolId(),
      entireBalance,
      address(this)
    );
  }

  function _liquidateReward() internal {
    // cache storage read to underlying() to save GAS,
    // added "_" such that we don't shadow BaseUpgradableStartegyStorage.rewardToken
    address rewardToken_ = rewardToken();

    // 1. sell secondRewardToken for rewardToken
    _sellSecondRewardToken(rewardToken_);

    // 2. sell rewardToken as usual
    uint256 rewardBalance = IERC20(rewardToken_).balanceOf(address(this));

    if (!sell() || rewardBalance < sellFloor()) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected(sell(), rewardBalance < sellFloor());
      return;
    }

    // transfer reward
    notifyProfitInRewardToken(rewardBalance);

    uint256 remainingRewardBalance = IERC20(rewardToken_).balanceOf(
      address(this)
    );

    if (remainingRewardBalance == 0) {
      return;
    }

    // cache storage read to underlying() to save GAS,
    // added "_" such that we don't shadow BaseUpgradableStartegyStorage.underlying
    address underlying_ = underlying();

    address uniLPComponentToken0 = IUniswapV2Pair(underlying_).token0();
    address uniLPComponentToken1 = IUniswapV2Pair(underlying_).token1();

    uint256 toToken0 = remainingRewardBalance.div(2);
    uint256 toToken1 = remainingRewardBalance.sub(toToken0);

    uint256 token0Amount;

    if (
      storedLiquidationDexes[rewardToken_][uniLPComponentToken0].length >
      0
    ) {
      // sell reward token to token0
      _swapTokenOnMultipleDEXes({
        _fromToken: rewardToken_,
        _toToken: uniLPComponentToken0,
        _amount: toToken0
      });
      token0Amount = IERC20(uniLPComponentToken0).balanceOf(
        address(this)
      );
    } else {
      // otherwise we assme token0 is the reward token itself
      token0Amount = toToken0;
    }

    uint256 token1Amount;

    if (
      storedLiquidationDexes[rewardToken_][uniLPComponentToken1].length >
      0
    ) {
      // sell reward token to token1
      _swapTokenOnMultipleDEXes({
        _fromToken: rewardToken_,
        _toToken: uniLPComponentToken1,
        _amount: toToken1
      });
      token1Amount = IERC20(uniLPComponentToken1).balanceOf(
        address(this)
      );
    } else {
      token1Amount = toToken1;
    }

    _addLiquidityToGetLptokens(
      uniLPComponentToken0,
      uniLPComponentToken1,
      token0Amount,
      token1Amount
    );
  }

  function _sellSecondRewardToken(address _rewardToken) internal {
    // sell secondRewardToken for rewardToken
    address secondRewardToken = getSecondRewardToken();
    uint256 secondRewardBalance = IERC20(secondRewardToken).balanceOf(
      address(this)
    );
    if (secondRewardBalance == 0) {
      return;
    }

    _swapTokenOnMultipleDEXes({
      _fromToken: secondRewardToken,
      _toToken: _rewardToken,
      _amount: secondRewardBalance
    });
  }

  function _swapTokenOnMultipleDEXes(
    address _fromToken,
    address _toToken,
    uint256 _amount
  ) internal {
    address universalLiquidator_ = universalLiquidator();

    IERC20(_fromToken).safeApprove(universalLiquidator_, 0);
    IERC20(_fromToken).safeApprove(universalLiquidator_, _amount);

    ILiquidator(universalLiquidator_).swapTokenOnMultipleDEXes(
      _amount,
      1,
      address(this), // target
      storedLiquidationDexes[_fromToken][_toToken],
      storedLiquidationPaths[_fromToken][_toToken]
    );
  }

  function _addLiquidityToGetLptokens(
    address _lpToken0,
    address _lpToken1,
    uint256 _token0Amount,
    uint256 _token1Amount
  ) internal {
    // get the routerV2 address such that we can add liquidity
    address routerV2 = getRouterV2();

    // provide token0 and token1 to the liquidity pool
    IERC20(_lpToken0).safeApprove(routerV2, 0);
    IERC20(_lpToken0).safeApprove(routerV2, _token0Amount);

    IERC20(_lpToken1).safeApprove(routerV2, 0);
    IERC20(_lpToken1).safeApprove(routerV2, _token1Amount);

    // provide liquidity to the liquidity pool to get lp tokens
    uint256 liquidity;
    (, , liquidity) = IUniswapV2Router02(routerV2).addLiquidity(
      _lpToken0,
      _lpToken1,
      _token0Amount,
      _token1Amount,
      1, // we are willing to take whatever the pair gives us
      1, // we are willing to take whatever the pair gives us
      address(this),
      block.timestamp
    );
  }

  /*
     *   Stakes everything the strategy holds into the reward pool
     */
  function _investAllUnderlying() internal onlyNotPausedInvesting {
    // this check is needed, because most of the SNX reward pools will revert if
    // you try to stake(0).
    if (IERC20(underlying()).balanceOf(address(this)) > 0) {
      _enterRewardPool();
    }
  }

  /*///////////////////////////////////////////////////////////////
                  PUBLIC EMERGENCY FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function emergencyExit() public onlyGovernance {
    _emergencyExitRewardPool();
    _setPausedInvesting(true);
  }

  function continueInvesting() public onlyGovernance {
    _setPausedInvesting(false);
  }

  /*///////////////////////////////////////////////////////////////
                  ISTRATEGY FUNCTION IMPLEMENTATIONS
  //////////////////////////////////////////////////////////////*/

  /*
     *   Withdraws all the asset to the vault
     */
  function withdrawAllToVault() public restricted {
    if (address(rewardPool()) != address(0)) {
      _exitRewardPool();
    }
    _liquidateReward();
    // cache storage read to underlying()
    address underlying_ = underlying();
    IERC20(underlying_).safeTransfer(
      vault(),
      IERC20(underlying_).balanceOf(address(this))
    );
  }

  /*
     *   Withdraws an amount of the underlying asset to the vault
     */
  function withdrawToVault(uint256 _amount) public restricted {
    // Typically there wouldn't be any amount here
    // however, it is possible because of the emergencyExit
    address underlying_ = underlying();
    uint256 entireBalance = IERC20(underlying_).balanceOf(address(this));

    if (_amount > entireBalance) {
      // While we have the check above, we still using SafeMath below
      // for the peace of mind (in case something gets changed in between)
      uint256 needToWithdraw = _amount.sub(entireBalance);
      uint256 toWithdraw = Math.min(_rewardPoolBalance(), needToWithdraw);
      IMasterChefV2(rewardPool()).withdraw(
        poolId(),
        toWithdraw,
        address(this)
      );
    }

    IERC20(underlying_).safeTransfer(vault(), _amount);
  }

  /*
     *   Note that we currently do not have a mechanism here to include the
     *   amount of reward that is accrued.
     */
  function investedUnderlyingBalance() external view returns (uint256) {
    uint256 balanceUnderlying = IERC20(underlying()).balanceOf(
      address(this)
    );

    if (rewardPool() == address(0)) {
      return balanceUnderlying;
    }
    // Adding the amount locked in the reward pool and the amount that is somehow in this contract
    // both are in the units of "underlying"
    // The second part is needed because there is the emergency exit mechanism
    // which would break the assumption that all the funds are always inside of the reward pool
    return _rewardPoolBalance().add(balanceUnderlying);
  }

  /*
     *   Governance or Controller can claim coins that are somehow transferred into the contract
     *   Note that they cannot come in take away coins that are used and defined in the strategy itself
     */
  function salvage(
    address _recipient,
    address _token,
    uint256 _amount
  ) external onlyControllerOrGovernance {
    // To make sure that governance cannot come in and take away the coins
    require(
      !unsalvagableTokens(_token),
      "token is defined as not salvagable"
    );
    IERC20(_token).safeTransfer(_recipient, _amount);
  }

  function unsalvagableTokens(address _token) public view returns (bool) {
    return (_token == rewardToken() ||
      _token == underlying() ||
      _token == getSecondRewardToken());
  }

  /*
     *   Get the reward, sell it in exchange for underlying, invest what you got.
     *   It's not much, but it's honest work.
     *
     *   Note that although `onlyNotPausedInvesting` is not added here,
     *   calling `_investAllUnderlying()` affectively blocks the usage of `doHardWork`
     *   when the investing is being paused by governance.
     */
  function doHardWork() external onlyNotPausedInvesting restricted {
    _harvestPoolRewards();
    _liquidateReward();
    _investAllUnderlying();
  }

  function depositArbCheck() public view returns (bool) {
    return true;
  }
}
