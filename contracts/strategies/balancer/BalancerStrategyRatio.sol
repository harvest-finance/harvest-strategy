pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "../../base/upgradability/BaseUpgradeableStrategyUL.sol";
import "../../base/interface/uniswap/IUniswapV2Pair.sol";
import "./interface/IBVault.sol";

contract BalancerStrategyRatio is IStrategy, BaseUpgradeableStrategyUL {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
  bytes32 internal constant _POOLID_SLOT = 0x3fd729bfa2e28b7806b03a6e014729f59477b530f995be4d51defc9dad94810b;
  bytes32 internal constant _BVAULT_SLOT = 0x85cbd475ba105ca98d9a2db62dcf7cf3c0074b36303ef64160d68a3e0fdd3c67;
  bytes32 internal constant _POOL_RATIO_SLOT = 0x5035d5d1de514bace8329602f2219cf1405001cc4a9602199da87cd5f4f17032;
  bytes32 internal constant _LIQUIDATION_RATIO_SLOT = 0x88a908c31cfd33a7a64870721e6da89f529116031d2cb9ed0bf1c4ba0873d19f;

  // this would be reset on each upgrade
  mapping (address => address[]) public swapRoutes;

  constructor() public BaseUpgradeableStrategyUL() {
    assert(_POOLID_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.poolId")) - 1));
    assert(_BVAULT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.bVault")) - 1));
    assert(_POOL_RATIO_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.poolRatio")) - 1));
    assert(_LIQUIDATION_RATIO_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.liquidationRatio")) - 1));
  }

  function initializeStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    address _rewardToken,
    address _bVault,
    bytes32 _poolID,
    uint256 _liquidationRatio,
    uint256 _ratioToken0
  ) public initializer {

    BaseUpgradeableStrategyUL.initialize(
      _storage,
      _underlying,
      _vault,
      _rewardPool,
      _rewardToken,
      300, // profit sharing numerator
      1000, // profit sharing denominator
      true, // sell
      1e18, // sell floor
      12 hours, // implementation change delay
      address(0x7882172921E99d590E097cD600554339fBDBc480) //UL Registry
    );

    (address _lpt,) = IBVault(_bVault).getPool(_poolID);
    require(_lpt == _underlying, "Underlying mismatch");
    require(_ratioToken0 < 1000, "Invalid ratio"); //Ratio base = 1000
    require(_liquidationRatio < 1000, "Invalid ratio"); //Ratio base = 1000

    setLiquidationRatio(_liquidationRatio);
    _setPoolRatio(_ratioToken0);
    _setPoolId(_poolID);
    _setBVault(_bVault);
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  function underlyingBalance() internal view returns (uint256 bal) {
      bal = IERC20(underlying()).balanceOf(address(this));
  }

  function unsalvagableTokens(address token) public view returns (bool) {
    return (token == rewardToken() || token == underlying());
  }

  // We assume that all the tradings can be done on Uniswap
  function _liquidateReward(uint256 rewardAmount) internal {
    if (!sell() || rewardAmount < sellFloor()) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected(sell(), rewardAmount < sellFloor());
      return;
    }

    uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    notifyProfitInRewardToken(rewardAmount);
    uint256 remainingRewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    uint256 toLiquidate = rewardAmount.sub(rewardBalance.sub(remainingRewardBalance));

    if (toLiquidate == 0) {
      return;
    }

    // allow Uniswap to sell our reward
    IERC20(rewardToken()).safeApprove(universalLiquidator(), 0);
    IERC20(rewardToken()).safeApprove(universalLiquidator(), toLiquidate);

    (IERC20[] memory componentTokens,,) = IBVault(bVault()).getPoolTokens(poolId());
    address lpComponentToken0 = address(componentTokens[0]);
    address lpComponentToken1 = address(componentTokens[1]);

    uint256 toToken0 = toLiquidate.mul(poolRatio()).div(1000);
    uint256 toToken1 = toLiquidate.sub(toToken0);

    uint256 token0Amount;

    if (storedLiquidationDexes[rewardToken()][lpComponentToken0].length > 0) {
      // if we need to liquidate the token0
      ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
        toToken0,
        1,
        address(this), // target
        storedLiquidationDexes[rewardToken()][lpComponentToken0],
        storedLiquidationPaths[rewardToken()][lpComponentToken0]
      );
      token0Amount = IERC20(lpComponentToken0).balanceOf(address(this));
    } else {
      // otherwise we assme token0 is the reward token itself
      token0Amount = toToken0;
    }

    uint256 token1Amount;

    if (storedLiquidationDexes[rewardToken()][lpComponentToken1].length > 0) {
      // sell reward token to token1
      ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
        toToken1,
        1,
        address(this), // target
        storedLiquidationDexes[rewardToken()][lpComponentToken1],
        storedLiquidationPaths[rewardToken()][lpComponentToken1]
      );
      token1Amount = IERC20(lpComponentToken1).balanceOf(address(this));
    } else {
      token1Amount = toToken1;
    }

    // provide token1 and token2 to Balancer
    IERC20(lpComponentToken0).safeApprove(bVault(), 0);
    IERC20(lpComponentToken0).safeApprove(bVault(), token0Amount);

    IERC20(lpComponentToken1).safeApprove(bVault(), 0);
    IERC20(lpComponentToken1).safeApprove(bVault(), token1Amount);

    IAsset[] memory assets = new IAsset[](2);
    assets[0] = IAsset(lpComponentToken0);
    assets[1] = IAsset(lpComponentToken1);

    IBVault.JoinKind joinKind = IBVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT;
    uint256[] memory amountsIn = new uint256[](2);
    amountsIn[0] = token0Amount;
    amountsIn[1] = token1Amount;
    uint256 minAmountOut = 1;

    bytes memory userData = abi.encode(joinKind, amountsIn, minAmountOut);

    IBVault.JoinPoolRequest memory request;
    request.assets = assets;
    request.maxAmountsIn = amountsIn;
    request.userData = userData;
    request.fromInternalBalance = false;

    IBVault(bVault()).joinPool(
      poolId(),
      address(this),
      address(this),
      request
      );
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawAllToVault() public restricted {
    uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    _liquidateReward(rewardBalance);
    IERC20(underlying()).safeTransfer(vault(), IERC20(underlying()).balanceOf(address(this)));
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawToVault(uint256 amount) public restricted {
    // Typically there wouldn't be any amount here
    // however, it is possible because of the emergencyExit
    uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));

    if (amount >= entireBalance){
      withdrawAllToVault();
    } else {
      IERC20(underlying()).safeTransfer(vault(), amount);
    }
  }

  /*
  *   Note that we currently do not have a mechanism here to include the
  *   amount of reward that is accrued.
  */
  function investedUnderlyingBalance() external view returns (uint256) {
    return underlyingBalance();
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
    uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    _liquidateReward(rewardBalance.mul(liquidationRatio()).div(1000));
  }

  function liquidateAll() external onlyGovernance {
    uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    _liquidateReward(rewardBalance);
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
  function _setPoolId(bytes32 _value) internal {
    setBytes32(_POOLID_SLOT, _value);
  }

  function poolId() public view returns (bytes32) {
    return getBytes32(_POOLID_SLOT);
  }

  function _setBVault(address _address) internal {
    setAddress(_BVAULT_SLOT, _address);
  }

  function bVault() public view returns (address) {
    return getAddress(_BVAULT_SLOT);
  }

  function _setPoolRatio(uint256 _ratio) internal {
    setUint256(_POOL_RATIO_SLOT, _ratio);
  }

  function poolRatio() public view returns (uint256) {
    return getUint256(_POOL_RATIO_SLOT);
  }

  function setLiquidationRatio(uint256 _ratio) public onlyGovernance {
    require(_ratio < 1000, "Invalid ratio"); //Ratio base = 1000
    setUint256(_LIQUIDATION_RATIO_SLOT, _ratio);
  }

  function liquidationRatio() public view returns (uint256) {
    return getUint256(_LIQUIDATION_RATIO_SLOT);
  }

  function setBytes32(bytes32 slot, bytes32 _value) internal {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      sstore(slot, _value)
    }
  }

  function getBytes32(bytes32 slot) internal view returns (bytes32 str) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      str := sload(slot)
    }
  }

  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
    // reset the liquidation paths
    // they need to be re-set manually
    (IERC20[] memory componentTokens,,) = IBVault(bVault()).getPoolTokens(poolId());
    address lpComponentToken0 = address(componentTokens[0]);
    address lpComponentToken1 = address(componentTokens[1]);
    storedLiquidationPaths[rewardToken()][lpComponentToken0] = new address[](0);
    storedLiquidationDexes[rewardToken()][lpComponentToken0] = new bytes32[](0);
    storedLiquidationPaths[rewardToken()][lpComponentToken1] = new address[](0);
    storedLiquidationDexes[rewardToken()][lpComponentToken1] = new bytes32[](0);
  }
}
