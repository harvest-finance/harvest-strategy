pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "../../base/upgradability/BaseUpgradeableStrategy.sol";
import "../../base/interface/uniswap/IUniswapV2Pair.sol";
import "./interface/IBVault.sol";

contract BalancerStrategy is IStrategy, BaseUpgradeableStrategy {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public constant uniswapRouterV2 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public constant sushiswapRouterV2 = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

  // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
  bytes32 internal constant _POOLID_SLOT = 0x3fd729bfa2e28b7806b03a6e014729f59477b530f995be4d51defc9dad94810b;
  bytes32 internal constant _USE_UNI_SLOT = 0x1132c1de5e5b6f1c4c7726265ddcf1f4ae2a9ecf258a0002de174248ecbf2c7a;
  bytes32 internal constant _BVAULT_SLOT = 0x85cbd475ba105ca98d9a2db62dcf7cf3c0074b36303ef64160d68a3e0fdd3c67;

  // this would be reset on each upgrade
  mapping (address => address[]) public swapRoutes;

  constructor() public BaseUpgradeableStrategy() {
    assert(_POOLID_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.poolId")) - 1));
    assert(_USE_UNI_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.useUni")) - 1));
    assert(_BVAULT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.bVault")) - 1));
  }

  function initializeStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    address _rewardToken,
    address _bVault,
    bytes32 _poolID,
    bool _useUni
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

    (address _lpt,) = IBVault(_bVault).getPool(_poolID);
    require(_lpt == _underlying, "Underlying mismatch");

    _setPoolId(_poolID);
    _setBVault(_bVault);

    (IERC20[] memory componentTokens,,) = IBVault(bVault()).getPoolTokens(poolId());

    address lpComponentToken0 = address(componentTokens[0]);
    address lpComponentToken1 = address(componentTokens[1]);

    // these would be required to be initialized separately by governance
    swapRoutes[lpComponentToken0] = new address[](0);
    swapRoutes[lpComponentToken1] = new address[](0);

    setBoolean(_USE_UNI_SLOT, _useUni);
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

  function setLiquidationPath(address _token, address [] memory _route) public onlyGovernance {
    swapRoutes[_token] = _route;
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

    address routerV2;
    if(useUni()) {
      routerV2 = uniswapRouterV2;
    } else {
      routerV2 = sushiswapRouterV2;
    }

    // allow Uniswap to sell our reward
    IERC20(rewardToken()).safeApprove(routerV2, 0);
    IERC20(rewardToken()).safeApprove(routerV2, remainingRewardBalance);

    // we can accept 1 as minimum because this is called only by a trusted role
    uint256 amountOutMin = 1;

    (IERC20[] memory componentTokens,,) = IBVault(bVault()).getPoolTokens(poolId());
    address lpComponentToken0 = address(componentTokens[0]);
    address lpComponentToken1 = address(componentTokens[1]);

    uint256 toToken0 = remainingRewardBalance.div(2);
    uint256 toToken1 = remainingRewardBalance.sub(toToken0);

    uint256 token0Amount;

    if (swapRoutes[lpComponentToken0].length > 1) {
      // if we need to liquidate the token0
      IUniswapV2Router02(routerV2).swapExactTokensForTokens(
        toToken0,
        amountOutMin,
        swapRoutes[lpComponentToken0],
        address(this),
        block.timestamp
      );
      token0Amount = IERC20(lpComponentToken0).balanceOf(address(this));
    } else {
      // otherwise we assme token0 is the reward token itself
      token0Amount = toToken0;
    }

    uint256 token1Amount;

    if (swapRoutes[lpComponentToken1].length > 1) {
      // sell reward token to token1
      IUniswapV2Router02(routerV2).swapExactTokensForTokens(
        toToken1,
        amountOutMin,
        swapRoutes[lpComponentToken1],
        address(this),
        block.timestamp
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
    _liquidateReward();
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

  function setUseUni(bool _value) public onlyGovernance {
    setBoolean(_USE_UNI_SLOT, _value);
  }

  function useUni() public view returns (bool) {
    return getBoolean(_USE_UNI_SLOT);
  }

  function _setBVault(address _address) internal {
    setAddress(_BVAULT_SLOT, _address);
  }

  function bVault() public view returns (address) {
    return getAddress(_BVAULT_SLOT);
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
    swapRoutes[lpComponentToken0] = new address[](0);
    swapRoutes[lpComponentToken1] = new address[](0);
  }
}
