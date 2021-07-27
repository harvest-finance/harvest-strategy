pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../../base/interface/IStrategy.sol";
import "../../../base/interface/IVault.sol";
import "../../../base/upgradability/BaseUpgradeableStrategy.sol";
import "../../../base/interface/uniswap/IUniswapV2Pair.sol";
import "../interface/IMasterChefV2.sol";

contract ConvexStrategyLP is IStrategy, BaseUpgradeableStrategy {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public constant uniswapRouterV2 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public constant sushiswapRouterV2 = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant multiSigAddr = 0xF49440C1F012d041802b25A73e5B0B9166a75c02;

  // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
  bytes32 internal constant _POOLID_SLOT = 0x3fd729bfa2e28b7806b03a6e014729f59477b530f995be4d51defc9dad94810b;
  bytes32 internal constant _HODL_RATIO_SLOT = 0xb487e573671f10704ed229d25cf38dda6d287a35872859d096c0395110a0adb1;
  bytes32 internal constant _HODL_VAULT_SLOT = 0xc26d330f887c749cb38ae7c37873ff08ac4bba7aec9113c82d48a0cf6cc145f2;

  // this would be reset on each upgrade
  uint256 public constant hodlRatioBase = 10000;
  mapping (address => address[]) public WETH2deposit;
  mapping (address => address[]) public reward2WETH;
  mapping (address => bool) public useUni;
  address[] public rewardTokens;

  constructor() public BaseUpgradeableStrategy() {
    assert(_POOLID_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.poolId")) - 1));
    assert(_HODL_RATIO_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.hodlRatio")) - 1));
    assert(_HODL_VAULT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.hodlVault")) - 1));
  }

  function initializeBaseStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    uint256 _poolID
  ) public initializer {

    BaseUpgradeableStrategy.initialize(
      _storage,
      _underlying,
      _vault,
      _rewardPool,
      weth,
      300, // profit sharing numerator
      1000, // profit sharing denominator
      true, // sell
      1e18, // sell floor
      12 hours // implementation change delay
    );

    address _lpt = IMasterChefV2(rewardPool()).lpToken(_poolID);
    require(_lpt == underlying(), "Pool Info does not match underlying");
    _setPoolId(_poolID);

    address lpComponentToken0 = IUniswapV2Pair(underlying()).token0();
    address lpComponentToken1 = IUniswapV2Pair(underlying()).token1();

    // these would be required to be initialized separately by governance
    WETH2deposit[lpComponentToken0] = new address[](0);
    WETH2deposit[lpComponentToken1] = new address[](0);

    setHodlRatio(1000);
    setHodlVault(multiSigAddr);
    rewardTokens = new address[](0);
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  function rewardPoolBalance() internal view returns (uint256 bal) {
      (bal,) = IMasterChefV2(rewardPool()).userInfo(poolId(), address(this));
  }

  function exitRewardPool() internal {
      uint256 bal = rewardPoolBalance();
      if (bal != 0) {
          IMasterChefV2(rewardPool()).withdrawAndHarvest(poolId(), bal, address(this));
      }
  }

  function emergencyExitRewardPool() internal {
      uint256 bal = rewardPoolBalance();
      if (bal != 0) {
          IMasterChefV2(rewardPool()).emergencyWithdraw(poolId(), address(this));
      }
  }

  function unsalvagableTokens(address token) public view returns (bool) {
    return (token == rewardToken() || token == underlying());
  }

  function enterRewardPool() internal {
    uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));
    IERC20(underlying()).safeApprove(rewardPool(), 0);
    IERC20(underlying()).safeApprove(rewardPool(), entireBalance);
    IMasterChefV2(rewardPool()).deposit(poolId(), entireBalance, address(this));
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

  function setDepositLiquidationPath(address [] memory _route, bool _useUni) public onlyGovernance {
    require(_route[0] == weth, "Path should start with WETH");
    address lpComponentToken0 = IUniswapV2Pair(underlying()).token0();
    address lpComponentToken1 = IUniswapV2Pair(underlying()).token1();
    require(_route[_route.length-1] == lpComponentToken0 || _route[_route.length-1] == lpComponentToken1, "Path should end with lpComponent");
    WETH2deposit[_route[_route.length-1]] = _route;
    useUni[_route[_route.length-1]] = _useUni;
  }

  function setRewardLiquidationPath(address [] memory _route, bool _useUni) public onlyGovernance {
    require(_route[_route.length-1] == weth, "Path should end with WETH");
    bool isReward = false;
    for(uint256 i = 0; i < rewardTokens.length; i++){
      if (_route[0] == rewardTokens[i]) {
        isReward = true;
      }
    }
    require(isReward, "Path should start with a rewardToken");
    reward2WETH[_route[0]] = _route;
    useUni[_route[0]] = _useUni;
  }

  function addRewardToken(address _token, address[] memory _path2WETH, bool _useUni) public onlyGovernance {
    require(_path2WETH[_path2WETH.length-1] == weth, "Path should end with WETH");
    require(_path2WETH[0] == _token, "Path should start with rewardToken");
    rewardTokens.push(_token);
    reward2WETH[_token] = _path2WETH;
    useUni[_token] = _useUni;
  }

  // We assume that all the tradings can be done on Uniswap
  function _liquidateReward() internal {
    if (!sell()) {
      // Profits can be disabled for possible simplified and rapoolId exit
      emit ProfitsNotCollected(sell(), false);
      return;
    }

    for(uint256 i = 0; i < rewardTokens.length; i++){
      address token = rewardTokens[i];
      uint256 rewardBalance = IERC20(token).balanceOf(address(this));

      uint256 toHodl = rewardBalance.mul(hodlRatio()).div(hodlRatioBase);
      if (toHodl > 0) {
        IERC20(token).safeTransfer(hodlVault(), toHodl);
        rewardBalance = rewardBalance.sub(toHodl);
      }

      if (rewardBalance == 0 || reward2WETH[token].length < 2) {
        continue;
      }

      address routerV2;
      if(useUni[token]) {
        routerV2 = uniswapRouterV2;
      } else {
        routerV2 = sushiswapRouterV2;
      }
      IERC20(token).safeApprove(routerV2, 0);
      IERC20(token).safeApprove(routerV2, rewardBalance);
      // we can accept 1 as the minimum because this will be called only by a trusted worker
      IUniswapV2Router02(routerV2).swapExactTokensForTokens(
        rewardBalance, 1, reward2WETH[token], address(this), block.timestamp
      );
    }

    uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    notifyProfitInRewardToken(rewardBalance);
    uint256 remainingRewardBalance = IERC20(rewardToken()).balanceOf(address(this));

    if (remainingRewardBalance == 0) {
      return;
    }

    // we can accept 1 as minimum because this is called only by a trusted role
    uint256 amountOutMin = 1;

    address lpComponentToken0 = IUniswapV2Pair(underlying()).token0();
    address lpComponentToken1 = IUniswapV2Pair(underlying()).token1();

    uint256 toToken0 = remainingRewardBalance.div(2);
    uint256 toToken1 = remainingRewardBalance.sub(toToken0);

    uint256 token0Amount;

    if (WETH2deposit[lpComponentToken0].length > 1) {
      address routerV2;
      if(useUni[lpComponentToken0]) {
        routerV2 = uniswapRouterV2;
      } else {
        routerV2 = sushiswapRouterV2;
      }
      // allow Uniswap to sell our reward
      IERC20(rewardToken()).safeApprove(routerV2, 0);
      IERC20(rewardToken()).safeApprove(routerV2, toToken0);
      // if we need to liquidate the token0
      IUniswapV2Router02(routerV2).swapExactTokensForTokens(
        toToken0,
        amountOutMin,
        WETH2deposit[lpComponentToken0],
        address(this),
        block.timestamp
      );
      token0Amount = IERC20(lpComponentToken0).balanceOf(address(this));
    } else {
      // otherwise we assme token0 is the reward token itself
      token0Amount = toToken0;
    }

    uint256 token1Amount;

    if (WETH2deposit[lpComponentToken1].length > 1) {
      address routerV2;
      if(useUni[lpComponentToken1]) {
        routerV2 = uniswapRouterV2;
      } else {
        routerV2 = sushiswapRouterV2;
      }
      // allow Uniswap to sell our reward
      IERC20(rewardToken()).safeApprove(routerV2, 0);
      IERC20(rewardToken()).safeApprove(routerV2, toToken1);
      // sell reward token to token1
      IUniswapV2Router02(routerV2).swapExactTokensForTokens(
        toToken1,
        amountOutMin,
        WETH2deposit[lpComponentToken1],
        address(this),
        block.timestamp
      );
      token1Amount = IERC20(lpComponentToken1).balanceOf(address(this));
    } else {
      token1Amount = toToken1;
    }

    // provide token1 and token2 to SUSHI
    IERC20(lpComponentToken0).safeApprove(sushiswapRouterV2, 0);
    IERC20(lpComponentToken0).safeApprove(sushiswapRouterV2, token0Amount);

    IERC20(lpComponentToken1).safeApprove(sushiswapRouterV2, 0);
    IERC20(lpComponentToken1).safeApprove(sushiswapRouterV2, token1Amount);

    // we provide liquidity to sushi
    uint256 liquidity;
    (,,liquidity) = IUniswapV2Router02(sushiswapRouterV2).addLiquidity(
      lpComponentToken0,
      lpComponentToken1,
      token0Amount,
      token1Amount,
      1,  // we are willing to take whatever the pair gives us
      1,  // we are willing to take whatever the pair gives us
      address(this),
      block.timestamp
    );
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
    exitRewardPool();
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
      IMasterChefV2(rewardPool()).withdraw(poolId(), toWithdraw, address(this));
    }

    IERC20(underlying()).safeTransfer(vault(), amount);
  }

  /*
  *   Note that we currently do not have a mechanism here to include the
  *   amount of reward that is accrued.
  */
  function investedUnderlyingBalance() external view returns (uint256) {
    // Adding the amount locked in the reward pool and the amount that is somehow in this contract
    // both are in the units of "underlying"
    // The second part is needed because there is the emergency exit mechanism
    // which would break the assumption that all the funds are always inside of the reward pool
    return rewardPoolBalance().add(IERC20(underlying()).balanceOf(address(this)));
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
    IMasterChefV2(rewardPool()).harvest(poolId(), address(this));
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

  function setHodlRatio(uint256 _value) public onlyGovernance {
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

  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
    // reset the liquidation paths
    // they need to be re-set manually
    WETH2deposit[IUniswapV2Pair(underlying()).token0()] = new address[](0);
    WETH2deposit[IUniswapV2Pair(underlying()).token1()] = new address[](0);
  }
}
