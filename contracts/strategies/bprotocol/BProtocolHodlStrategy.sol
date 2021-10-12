pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "../../base/upgradability/BaseUpgradeableStrategyUL.sol";
import "../../base/sushi-base/interfaces/IMasterChef.sol";
import "../../base/interface/uniswap/IUniswapV2Pair.sol";
import "../../base/interface/weth/Weth9.sol";
import "../../base/PotPool.sol";
import "./interface/IBAMM.sol";
import "./interface/IStabilityPool.sol";

import "hardhat/console.sol";

contract BProtocolHodlStrategy is IStrategy, BaseUpgradeableStrategyUL {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  uint constant public PRECISION = 1e18;

  // additional storage slots (on top of BaseUpgradeableStrategyUL ones) are defined here
  bytes32 internal constant _HODLVAULT_SLOT = 0xc26d330f887c749cb38ae7c37873ff08ac4bba7aec9113c82d48a0cf6cc145f2;
  bytes32 internal constant _POTPOOL_SLOT = 0x7f4b50847e7d7a4da6a6ea36bfb188c77e9f093697337eb9a876744f926dd014;

  constructor() public BaseUpgradeableStrategyUL() {
    assert(_HODLVAULT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.hodlVault")) - 1));
    assert(_POTPOOL_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.potPool")) - 1));
  }

  function initializeBProtocolHodlStrategy(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    address _rewardToken,
    address _hodlVault,
    address _potPool
  ) public initializer {
    require(_rewardPool != address(0), "reward pool is empty");

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
    
    setAddress(_HODLVAULT_SLOT, _hodlVault);
    setAddress(_POTPOOL_SLOT, _potPool);
  }

  /**
   * Include fallback function to receive Ether when withdrawing from B.AMM
   * see failSafeSwapETHtoRewardToken function in this contract
   */
  function() external payable { }

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
  */
  function doHardWork() external onlyNotPausedInvesting restricted {
     // get the lqty tokens, potentially also some ETH although that should not happen
    IBAMM(rewardPool()).withdraw(0);
    // hodl lqty rewards into lqty pool
    _hodlAndNotify();
    investAllUnderlying();
  }

  function finalizeUpgrade() external onlyGovernance {
    _finalizeUpgrade();
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
    return rewardPoolBalance().add(IERC20(underlying()).balanceOf(address(this)));
  }

  function setHodlVault(address _value) public onlyGovernance {
    require(hodlVault() == address(0), "Hodl vault already set");
    setAddress(_HODLVAULT_SLOT, _value);
  }

  function setPotPool(address _value) public onlyGovernance {
    require(potPool() == address(0), "PotPool already set");
    setAddress(_POTPOOL_SLOT, _value);
  }

  /*
  *   Resumes the ability to invest into the underlying reward pools
  */
  function continueInvesting() public onlyGovernance {
    _setPausedInvesting(false);
  }
  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawAllToVault() public restricted {
    console.log('withdrawAllToVault');
    exitRewardPool();
    _hodlAndNotify();
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
      IBAMM(rewardPool()).withdraw(toWithdraw);
    }

    IERC20(underlying()).safeTransfer(vault(), amount);
  }

  function hodlVault() public view returns (address) {
    return getAddress(_HODLVAULT_SLOT);
  }

  function potPool() public view returns (address) {
    return getAddress(_POTPOOL_SLOT);
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  function unsalvagableTokens(address token) public view returns (bool) {
    return (token == rewardToken() || token == underlying());
  }

  function exitRewardPool() internal {
      // console.log('exitRewardPool');
      // address stabilityPool = IBAMM(rewardPool()).SP();

      // uint lusdValue = IStabilityPool(stabilityPool).getCompoundedLUSDDeposit(rewardPool());
      // uint ethValue = IStabilityPool(stabilityPool).getDepositorETHGain(rewardPool()).add(rewardPool().balance);
      // console.log('lusdValue', lusdValue);
      // console.log('ethValue', ethValue);

      // uint total = IBAMM(rewardPool()).totalSupply();

      // uint lusdAmount = lusdValue.mul(rewardPoolBalance()).div(total);
      // uint ethAmount = ethValue.mul(rewardPoolBalance()).div(total);
      // console.log('lusdAmount', lusdAmount);
      // console.log('ethAmount', ethAmount);

      // uint price = 3523440000000000000000;

      // uint totalValue = lusdValue.add(ethValue.mul(price) / PRECISION);
      // console.log('totalValue', totalValue);

      // uint newShare = PRECISION;
      // if(total > 0) newShare = total.mul(lusdAmount) / totalValue;
      // console.log('newShare', newShare);

      uint256 bal = rewardPoolBalance();
      // console.log('rewardPoolBalance before', bal);
      if (bal != 0) {
          console.log('withdrawing all shares', bal);
          console.log('shares are worth in LUSD:', rewardPoolLusdBalance());
          IBAMM(rewardPool()).withdraw(bal);
      }

      console.log('ETH now in HodlStrategy', address(this).balance);


      // console.log('withdrawing newShare', newShare);
      // IBAMM(rewardPool()).withdraw(newShare);

      /**
       * @dev Note that the IBAMM does not implement an emergency exit
       * But deposits shouldn't be locked even if rewards are 0
       * The only case where deposits wouldn't be withdrawable is if 
       * bProtocol fails to correctly collaterize their LQTY trove with ETH
       */
  }

  function enterRewardPool() internal {
    uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));
    console.log('entireBalance', entireBalance);
    IERC20(underlying()).safeApprove(rewardPool(), 0);
    IERC20(underlying()).safeApprove(rewardPool(), entireBalance);
    IBAMM(rewardPool()).deposit(entireBalance);
    console.log('depositing LUSD', entireBalance);
    uint bal = IBAMM(rewardPool()).balanceOf(address(this));
    console.log('rewardPool balance in B.AMM LUSD-ETH of this', bal);
  }
  

  // We Hodl all the rewards
  function _hodlAndNotify() internal {
    failSafeSwapETHtoRewardToken();

    // take profit
    uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    console.log('rewardBalance', rewardBalance);
    notifyProfitInRewardToken(rewardBalance);

    // check if any remaining reward balance exists, if not return
    uint256 remainingRewardBalance = IERC20(rewardToken()).balanceOf(address(this));
    console.log('remainingRewardBalance', remainingRewardBalance);
    if (remainingRewardBalance == 0) {
      return;
    }

    // transfer the rest of the reward balance to the hodl vault
    IERC20(rewardToken()).safeApprove(hodlVault(), 0);
    IERC20(rewardToken()).safeApprove(hodlVault(), remainingRewardBalance);
    IVault(hodlVault()).deposit(remainingRewardBalance);

    // take the fTokens reward balance and distribute to the investors of this strategy
    uint256 fRewardBalance = IERC20(hodlVault()).balanceOf(address(this));
    IERC20(hodlVault()).safeTransfer(potPool(), fRewardBalance);
    PotPool(potPool()).notifyTargetRewardAmount(hodlVault(), fRewardBalance);
  }

  /**
    * Swaps all ETH to the reward token before hodling it
    * 
    * bProtocol should only be rewarding LQTY (reward token) and LUSD in theory, 
    * and LUSD is autocompounded by LQTY. ETH is "autocompounded" by bProtocol.
    * but the bProtocol smart contract code contains a payout for ETH too as a fail safe probably
    * in theory, there should not be any ETH there to pay out, but since they include that fail-safe we include one too
    * Thus we liquidate ETH to LQTY before hodling LQTY
    * 
    * bProtcol says about it:
    * the auto compounding process is not atomic and might take some time. Hence, there might be ETH left overs in the time of withdrawals. 
    * And as a user you will get it. since we went live it never was over 0.1% of total inventory, but in theory it could.
    * hence as a user your choice is to either wait for the process to be completed, or to withdraw now and get some of your withdrawals in ETH. 
    */
  function failSafeSwapETHtoRewardToken() internal {
    if(address(this).balance == 0) {
      console.log('no ETH in contract, no fail safe needed');
      return;
    }

    console.log('ETH in contract, fail safe needed!!', address(this).balance);
    // convert the received Ether into wrapped Ether
    WETH9(weth).deposit.value(address(this).balance)();
    // get weth balance
    uint256 wethBalance = IERC20(weth).balanceOf(address(this));

    // weth -> rewardToken
    IERC20(weth).safeApprove(universalLiquidator(), 0);
    IERC20(weth).safeApprove(universalLiquidator(), wethBalance);
    // we can accept 1 as the minimum because this will be called only by a trusted worker
    ILiquidator(universalLiquidator()).swapTokenOnMultipleDEXes(
      wethBalance,
      1,
      address(this), // target
      storedLiquidationDexes[weth][rewardToken()],
      storedLiquidationPaths[weth][rewardToken()]
    );
  }

  /*
  *   Stakes everything the strategy holds into the reward pool
  */
  function investAllUnderlying() internal onlyNotPausedInvesting {
    if(IERC20(underlying()).balanceOf(address(this)) > 0) {
      enterRewardPool();
    }
  }
      // uint price = IBAMM(rewardPool()).fetchPrice();
      // if(price == 0) {
      //   return 0;
      // }
    // uint userBalanceLusdEth = IBAMM(rewardPool()).balanceOf(address(this));
    // uint totalSupply = IBAMM(rewardPool()).totalSupply();
    // uint totalLusd = bammLusdTotal();
    // bal = totalLusd.mul(userBalanceLusdEth).div(totalSupply);
      // bal = IBAMM(rewardPool()).balanceOf(address(this));

  function bammLusdTotal() internal view returns (uint256 total) {
    address stabilityPool = IBAMM(rewardPool()).SP();
    total = IStabilityPool(stabilityPool).getCompoundedLUSDDeposit(rewardPool());
    console.log('This should increase: bammLusdTotal of stability Pool', total);
  }

  function rewardPoolBalance() internal view returns (uint256 bal) {
      // uint userBalanceLusdEth = IBAMM(rewardPool()).balanceOf(address(this));
      // uint totalSupply = IBAMM(rewardPool()).totalSupply();
      // uint totalLusd = bammLusdTotal();
      // bal = totalLusd.mul(userBalanceLusdEth).div(totalSupply);
      bal = IBAMM(rewardPool()).balanceOf(address(this));
  }

  function rewardPoolLusdBalance() public view returns (uint256 bal) {
      uint userBalanceLusdEth = IBAMM(rewardPool()).balanceOf(address(this));
      uint totalSupply = IBAMM(rewardPool()).totalSupply();
      uint totalLusd = bammLusdTotal();
      bal = totalLusd.mul(userBalanceLusdEth).div(totalSupply);
  }  
}
