pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "../../base/upgradability/BaseUpgradeableStrategyUL.sol";
import "../../base/interface/uniswap/IUniswapV2Pair.sol";
import "./interface/IAlkemiEarnPublic.sol";
import "./interface/IRewardControl.sol";
import "../../base/interface/weth/Weth9.sol";

contract AlkemiStrategy is IStrategy, BaseUpgradeableStrategyUL {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public constant wethAddr = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant multiSigAddr = address(0xF49440C1F012d041802b25A73e5B0B9166a75c02);

  // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
  bytes32 internal constant _ALKEMI_TOKEN_SLOT = 0x64ebd51c4e794221918d0decf03cb433a69ffbab192707e00b41ef0ce07f6217;
  bytes32 internal constant _SUPPLY_CONTRACT_SLOT = 0x52fbc10413f749a4bd118a304e2a9446461114a4bb64b3a69cdb9cca463f1e81;
  bytes32 internal constant _HODL_RATIO_SLOT = 0xb487e573671f10704ed229d25cf38dda6d287a35872859d096c0395110a0adb1;
  bytes32 internal constant _HODL_VAULT_SLOT = 0xc26d330f887c749cb38ae7c37873ff08ac4bba7aec9113c82d48a0cf6cc145f2;

  uint256 public constant hodlRatioBase = 10000;

  constructor() public BaseUpgradeableStrategyUL() {
    assert(_ALKEMI_TOKEN_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.alkemiToken")) - 1));
    assert(_SUPPLY_CONTRACT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.supplyContract")) - 1));
    assert(_HODL_RATIO_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.hodlRatio")) - 1));
    assert(_HODL_VAULT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.hodlVault")) - 1));
  }

  function initializeBaseStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    address _rewardToken,
    address _alkemiToken,
    address _supplyContract,
    uint256 _hodlRatio
  ) public initializer {
    uint256 profitSharingNumerator = 300;
    if (_hodlRatio >= 3000) {
      profitSharingNumerator = 0;
    } else if (_hodlRatio > 0){
      profitSharingNumerator = profitSharingNumerator.sub(_hodlRatio.div(10))
        .mul(hodlRatioBase)
        .div(hodlRatioBase.sub(_hodlRatio));
    }
    BaseUpgradeableStrategyUL.initialize(
      _storage,
      _underlying,
      _vault,
      _rewardPool,
      _rewardToken,
      profitSharingNumerator,  // profit sharing numerator
      1000, // profit sharing denominator
      true, // sell
      1e15, // sell floor
      12 hours, // implementation change delay
      address(0x7882172921E99d590E097cD600554339fBDBc480) //UL Registry
    );
    _setAlkemiToken(_alkemiToken);
    _setSupplyContract(_supplyContract);
    setHodlRatio(_hodlRatio);
    setHodlVault(multiSigAddr);
  }

  function setHodlRatio(uint256 _value) public onlyGovernance {
    require(_value <= hodlRatioBase, "Value cannot be higher than base");
    uint256 profitSharingNumerator = 300;
    if (_value >= 3000) {
      profitSharingNumerator = 0;
    } else if (_value > 0){
      profitSharingNumerator = profitSharingNumerator.sub(_value.div(10))
        .mul(hodlRatioBase)
        .div(hodlRatioBase.sub(_value));
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
      bal = IAlkemiEarnPublic(supplyContract()).getSupplyBalance(address(this), alkemiToken());
  }

  function exitRewardPool() internal {
      uint256 stakedBalance = rewardPoolBalance();
      if (stakedBalance != 0) {
          IAlkemiEarnPublic(supplyContract()).withdraw(alkemiToken(), stakedBalance);
          if (underlying() == wethAddr) {
            WETH9 weth = WETH9(wethAddr);
            weth.deposit.value(address(this).balance)();
          }
      }
  }

  function unsalvagableTokens(address token) public view returns (bool) {
    return (token == rewardToken() || token == underlying());
  }

  function enterRewardPool() internal {
    uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));
    if (underlying() == wethAddr) {
      WETH9 weth = WETH9(wethAddr);
      weth.withdraw(entireBalance); // Unwrapping
      IAlkemiEarnPublic(supplyContract()).supply.value(address(this).balance)(alkemiToken(), entireBalance);
    } else {
      IAlkemiEarnPublic(supplyContract()).supply(alkemiToken(), entireBalance);
    }
  }

  /*
  *   In case there are some issues discovered about the pool or underlying asset
  *   Governance can exit the pool properly
  *   The function is only used for emergency to exit the pool
  */
  function emergencyExit() public onlyGovernance {
    exitRewardPool();
    _setPausedInvesting(true);
  }

  /*
  *   Resumes the ability to invest into the underlying reward pools
  */

  function continueInvesting() public onlyGovernance {
    _setPausedInvesting(false);
  }

  // We assume that all the tradings can be done on Sushiswap
  function liquidateReward() internal {
    uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    if (!sell() || rewardBalance < sellFloor()) {
      // Profits can be disabled for possible simplified and rapoolId exit
      emit ProfitsNotCollected(sell(), rewardBalance < sellFloor());
      return;
    }

    uint256 toHodl = rewardBalance.mul(hodlRatio()).div(hodlRatioBase);
    if (toHodl > 0) {
      IERC20(rewardToken()).safeTransfer(hodlVault(), toHodl);
      rewardBalance = rewardBalance.sub(toHodl);
      if (rewardBalance == 0) {
        return;
      }
    }

    if (storedLiquidationDexes[rewardToken()][underlying()].length < 1) {
      return;
    }

    rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    notifyProfitInRewardToken(rewardBalance);
    uint256 remainingRewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    if (remainingRewardBalance == 0) {
      return;
    }

    IERC20(rewardToken()).safeApprove(universalLiquidator(), 0);
    IERC20(rewardToken()).safeApprove(universalLiquidator(), remainingRewardBalance);
    // we can accept 1 as the minimum because this will be called only by a trusted worker
    ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
      remainingRewardBalance,
      1,
      address(this), // target
      storedLiquidationDexes[rewardToken()][underlying()],
      storedLiquidationPaths[rewardToken()][underlying()]
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
    if (address(rewardPool()) != address(0)) {
      exitRewardPool();
    }
    IRewardControl(rewardPool()).claimAlk(address(this));
    liquidateReward();
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
      IAlkemiEarnPublic(supplyContract()).withdraw(alkemiToken(), toWithdraw);
      if (underlying() == wethAddr) {
        WETH9 weth = WETH9(wethAddr);
        weth.deposit.value(address(this).balance)();
      }
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
    IRewardControl(rewardPool()).claimAlk(address(this));
    liquidateReward();
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

  function _setAlkemiToken(address _address) internal {
    setAddress(_ALKEMI_TOKEN_SLOT, _address);
  }

  function alkemiToken() public view returns (address) {
    return getAddress(_ALKEMI_TOKEN_SLOT);
  }

  function _setSupplyContract(address _address) internal {
    setAddress(_SUPPLY_CONTRACT_SLOT, _address);
  }

  function supplyContract() public view returns (address) {
    return getAddress(_SUPPLY_CONTRACT_SLOT);
  }

  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
  }

  function () external payable {} // this is needed for the WETH unwrapping
}
