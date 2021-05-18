pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/StrategyBaseClaimable.sol";
import "../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../base/interface/IVault.sol";
import "../../base/interface/uniswap/IUniswapV2Pair.sol";
import "./interfaces/ISharePool.sol";
import "./interfaces/IBoardRoom.sol";

import "hardhat/console.sol";

/*
*   This is a general strategy for yields that are based on the synthetix reward contract
*   for example, yam, spaghetti, ham, shrimp.
*
*   One strategy is deployed for one underlying asset, but the design of the contract
*   should allow it to switch between different reward contracts.
*
*   It is important to note that not all SNX reward contracts that are accessible via the same interface are
*   suitable for this Strategy. One concrete example is CREAM.finance, as it implements a "Lock" feature and
*   would not allow the user to withdraw within some timeframe after the user have deposited.
*   This would be problematic to user as our "invest" function in the vault could be invoked by anyone anytime
*   and thus locking/reverting on subsequent withdrawals. Another variation is the YFI Governance: it can
*   activate a vote lock to stop withdrawal.
*
*   Ref:
*   1. CREAM https://etherscan.io/address/0xc29e89845fa794aa0a0b8823de23b760c3d766f5#code
*   2. YAM https://etherscan.io/address/0x8538E5910c6F80419CD3170c26073Ff238048c9E#code
*   3. SHRIMP https://etherscan.io/address/0x9f83883FD3cadB7d2A83a1De51F9Bf483438122e#code
*   4. BASED https://etherscan.io/address/0x5BB622ba7b2F09BF23F1a9b509cd210A818c53d7#code
*   5. YFII https://etherscan.io/address/0xb81D3cB2708530ea990a287142b82D058725C092#code
*   6. YFIGovernance https://etherscan.io/address/0xBa37B002AbaFDd8E89a1995dA52740bbC013D992#code
*
*
*
*   Respecting the current system design of choosing the best strategy under the vault, and also rewarding/funding
*   the public key that invokes the switch of strategies, this smart contract should be deployed twice and linked
*   to the same vault. When the governance want to rotate the crop, they would set the reward source on the strategy
*   that is not active, then set that apy higher and this one lower.
*
*   Consequently, in the smart contract we restrict that we can only set a new reward source when it is not active.
*
*/

contract LiftStrategy is StrategyBaseClaimable {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public uniLPComponentToken0;
  address public uniLPComponentToken1;
  address public ctrl;

  bool public pausedInvesting = false; // When this flag is true, the strategy will not be able to invest. But users should be able to withdraw.

  ISharePool public rewardPool;
  IBoardRoom public boardRoom;

  uint256[2][] public stakes;
  uint256 public maxStakes;

  event ProfitsNotCollected();

  // This is only used in `investAllUnderlying()`
  // The user can still freely withdraw from the strategy
  modifier onlyNotPausedInvesting() {
    require(!pausedInvesting, "Action blocked as the strategy is in emergency state");
    _;
  }

  constructor(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardPool,
    address _rewardToken,
    address _uniswapRouterV2,
    uint256 _maxStakes
  )
  StrategyBaseClaimable(_storage, _underlying, _vault, _rewardToken, _rewardToken, _uniswapRouterV2)
  public {
    uniLPComponentToken0 = IUniswapV2Pair(underlying).token0();
    uniLPComponentToken1 = IUniswapV2Pair(underlying).token1();
    rewardPool = ISharePool(_rewardPool);
    boardRoom = IBoardRoom(rewardPool.boardroom());
    ctrl = boardRoom.control();
    maxStakes = _maxStakes;
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  /*
  *   In case there are some issues discovered about the pool or underlying asset
  *   Governance can exit the pool properly
  *   The function is only used for emergency to exit the pool
  */
  function emergencyExit() public onlyGovernance {
    rewardPool.exit();
    pausedInvesting = true;
  }

  /*
  *   Resumes the ability to invest into the underlying reward pools
  */

  function continueInvesting() public onlyGovernance {
    pausedInvesting = false;
  }

  /*
  *   Stakes everything the strategy holds into the reward pool
  */
  function investAllUnderlying() internal onlyNotPausedInvesting {
    // this check is needed, because most of the SNX reward pools will revert if
    // you try to stake(0).
    if(IERC20(underlying).balanceOf(address(this)) > 0) {
      IERC20(underlying).safeApprove(address(rewardPool), IERC20(underlying).balanceOf(address(this)));
      rewardPool.stake(IERC20(underlying).balanceOf(address(this)));
    }
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawAllToVault() public restricted {
    if (address(rewardPool) != address(0)) {
      if (rewardPool.balanceOf(address(this)) > 0) {
        rewardPool.exit();
      }
    }
    if (IERC20(underlying).balanceOf(address(this)) > 0) {
      IERC20(underlying).safeTransfer(vault, IERC20(underlying).balanceOf(address(this)));
    }
  }

  /*
  *   Withdraws all the asset to the vault
  */
  function withdrawToVault(uint256 amount) public restricted {
    // Typically there wouldn't be any amount here
    // however, it is possible because of the emergencyExit
    if(amount > IERC20(underlying).balanceOf(address(this))){
      // While we have the check above, we still using SafeMath below
      // for the peace of mind (in case something gets changed in between)
      uint256 needToWithdraw = amount.sub(IERC20(underlying).balanceOf(address(this)));
      rewardPool.withdraw(Math.min(rewardPool.balanceOf(address(this)), needToWithdraw));
    }
    IERC20(underlying).safeTransfer(vault, amount);
  }

  /*
  *   Note that we currently do not have a mechanism here to include the
  *   amount of reward that is accrued.
  */
  function investedUnderlyingBalance() external view returns (uint256) {
    if (address(rewardPool) == address(0)) {
      return IERC20(underlying).balanceOf(address(this));
    }
    // Adding the amount locked in the reward pool and the amount that is somehow in this contract
    // both are in the units of "underlying"
    // The second part is needed because there is the emergency exit mechanism
    // which would break the assumption that all the funds are always inside of the reward pool
    return rewardPool.balanceOf(address(this)).add(IERC20(underlying).balanceOf(address(this)));
  }

  /*
  *   Governance or Controller can claim coins that are somehow transferred into the contract
  *   Note that they cannot come in take away coins that are used and defined in the strategy itself
  *   Those are protected by the "unsalvagableTokens". To check, see where those are being flagged.
  */
  function salvage(address recipient, address token, uint256 amount) external onlyControllerOrGovernance {
     // To make sure that governance cannot come in and take away the coins
    require(!unsalvagableTokens[token], "token is defined as not salvagable");
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
    uint256 len = stakes.length;
    require(len<=maxStakes, "Too many stakes, withdraw or increase maxStakes first");
    uint256 rewardBalanceBefore = boardRoom.getbalanceOfShare(address(this));
    rewardPool.stakeInBoardroom();
    uint256 rewardBalanceAfter = boardRoom.getbalanceOfShare(address(this));
    uint256 rewardStaked = rewardBalanceAfter.sub(rewardBalanceBefore);
    if (rewardStaked > 0) {
      stakes.push([block.timestamp, rewardStaked]);
    }
    investAllUnderlying();
  }

  function _getReward() internal {
    uint256 len = stakes.length;
    require(len<=maxStakes, "Too many stakes, withdrawor increase maxStakes first");
    uint256 rewardBalanceBefore = boardRoom.getbalanceOfShare(address(this));
    rewardPool.stakeInBoardroom();
    uint256 rewardBalanceAfter = boardRoom.getbalanceOfShare(address(this));
    uint256 rewardStaked = rewardBalanceAfter.sub(rewardBalanceBefore);
    if (rewardStaked > 0) {
      stakes.push([block.timestamp, rewardStaked]);
    }
  }

  function withdrawRewardShareOldest() external onlyMultiSigOrGovernance {
    require(allowedRewardClaimable, "reward claimable is not allowed");
    uint256 len = stakes.length;
    require(len>0, "no stakes");

    uint256 time = stakes[0][0];
    boardRoom.withdrawShare(time);
    uint256 shareBalance = IERC20(rewardToken).balanceOf(address(this));
    IERC20(rewardToken).safeTransfer(msg.sender, shareBalance);

    //clean up the list of stakes
    uint256 i = 0;
    for (i;i<(len.sub(1));i++) {
      stakes[i] = stakes[i+1];
    }
    stakes.pop();
  }

  function withdrawRewardShareNewest() external onlyMultiSigOrGovernance {
    require(allowedRewardClaimable, "reward claimable is not allowed");
    uint256 len = stakes.length;
    require(len>0, "no stakes");

    uint256 time = stakes[len.sub(1)][0];
    boardRoom.withdrawShare(time);
    uint256 shareBalance = IERC20(rewardToken).balanceOf(address(this));
    IERC20(rewardToken).safeTransfer(msg.sender, shareBalance);
    stakes.pop();
  }

  function withdrawRewardShareAll() external onlyMultiSigOrGovernance {
    require(allowedRewardClaimable, "reward claimable is not allowed");
    uint256 len = stakes.length;
    require(len>0, "no stakes");
    boardRoom.withdrawShareDontCallMeUnlessYouAreCertain();
    uint256 shareBalance = IERC20(rewardToken).balanceOf(address(this));
    IERC20(rewardToken).safeTransfer(msg.sender, shareBalance);
    uint256 i = 0;
    for (i;i<len;i++) {
      stakes.pop();
    }
  }

  function withdrawRewardControl() external onlyMultiSigOrGovernance {
    require(allowedRewardClaimable, "reward claimable is not allowed");
    boardRoom.claimReward();
    uint256 ctrlBalance = IERC20(ctrl).balanceOf(address(this));
    IERC20(ctrl).safeTransfer(msg.sender, ctrlBalance);
  }

  function pendingControl() external view returns(uint256){
    return boardRoom.earned(address(this));
  }

  function stakedLift() external view returns(uint256){
    return boardRoom.getbalanceOfShare(address(this));
  }

  function setMaxStakes(uint256 _maxStakes) external onlyGovernance {
    require(stakes.length <= _maxStakes, "Current number of stakes too high");
    maxStakes = _maxStakes;
  }

  function stakesLength() external view returns(uint256) {
    return stakes.length;
  }

}
