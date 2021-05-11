//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;

import "./inheritance/RewardTokenProfitNotifier.sol";
import "./interface/IStrategy.sol";

import "./interface/ILiquidator.sol";
import "./interface/ILiquidatorRegistry.sol";

contract StrategyBaseULClaimable is IStrategy, RewardTokenProfitNotifier  {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  event ProfitsNotCollected(address);
  event Liquidating(address, uint256);

  address public underlying;
  address public vault;
  mapping (address => bool) public unsalvagableTokens;
  address public universalLiquidatorRegistry;

  address public rewardTokenForLiquidation;
  bool public allowedRewardClaimable = false;
  address public multiSig = 0xF49440C1F012d041802b25A73e5B0B9166a75c02;

  modifier restricted() {
    require(msg.sender == vault || msg.sender == address(controller()) || msg.sender == address(governance()),
      "The sender has to be the controller or vault or governance");
    _;
  }

  modifier onlyMultiSigOrGovernance() {
    require(msg.sender == multiSig || msg.sender == governance(), "The sender has to be multiSig or governance");
    _;
  }

  constructor(
    address _storage,
    address _underlying,
    address _vault,
    address _rewardTokenForLiquidation,
    address _rewardTokenForProfitSharing,
    address _universalLiquidatorRegistry
  ) RewardTokenProfitNotifier(_storage, _rewardTokenForProfitSharing) public {
    rewardTokenForLiquidation = _rewardTokenForLiquidation;
    underlying = _underlying;
    vault = _vault;
    unsalvagableTokens[_rewardTokenForLiquidation] = true;
    unsalvagableTokens[_underlying] = true;
    universalLiquidatorRegistry = _universalLiquidatorRegistry;
    require(underlying != _rewardTokenForLiquidation, "reward token cannot be the same as underlying for StrategyBaseULClaimable");
  }

  function universalLiquidator() public view returns(address) {
    return ILiquidatorRegistry(universalLiquidatorRegistry).universalLiquidator();
  }

  function setMultiSig(address _address) public onlyGovernance {
    multiSig = _address;
  }

  // reward claiming by multiSig for some strategies
  function claimReward() public onlyMultiSigOrGovernance {
    require(allowedRewardClaimable, "reward claimable is not allowed");
    _getReward();
    uint256 rewardBalance = IERC20(rewardTokenForLiquidation).balanceOf(address(this));
    IERC20(rewardTokenForLiquidation).safeTransfer(msg.sender, rewardBalance);
  }

  function setRewardClaimable(bool flag) public onlyGovernance {
    allowedRewardClaimable = flag;
  }

  function _getReward() internal {
    revert("Should be implemented in the derived contract");
  }
}
