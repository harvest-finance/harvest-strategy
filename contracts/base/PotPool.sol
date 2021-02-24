// SPDX-License-Identifier: MIT
pragma solidity 0.5.16;

import "./inheritance/Controllable.sol";
import "./interface/IController.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

contract IRewardDistributionRecipient is Ownable {

    mapping (address => bool) public rewardDistribution;

    constructor(address[] memory _rewardDistributions) public {
        // NotifyHelper
        rewardDistribution[0xE20c31e3d08027F5AfACe84A3A46B7b3B165053c] = true;

        // FeeRewardForwarderV5
        rewardDistribution[0x3D135252D366111cf0621eB0e846243CBb962061] = true;

        for(uint256 i = 0; i < _rewardDistributions.length; i++) {
          rewardDistribution[_rewardDistributions[i]] = true;
        }
    }

    function notifyTargetRewardAmount(address rewardToken, uint256 reward) external;
    function notifyRewardAmount(uint256 reward) external;

    modifier onlyRewardDistribution() {
        require(rewardDistribution[_msgSender()], "Caller is not reward distribution");
        _;
    }

    function setRewardDistribution(address[] calldata _newRewardDistribution, bool _flag)
        external
        onlyOwner
    {
        for(uint256 i = 0; i < _newRewardDistribution.length; i++){
          rewardDistribution[_newRewardDistribution[i]] = _flag;
        }
    }
}

contract PotPool is IRewardDistributionRecipient, Controllable, ERC20, ERC20Detailed {

    using Address for address;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public lpToken;
    uint256 public duration; // making it not a constant is less gas efficient, but portable

    mapping(address => uint256) public stakedBalanceOf;

    mapping (address => bool) smartContractStakers;
    address[] public rewardTokens;
    mapping(address => uint256) public periodFinishForToken;
    mapping(address => uint256) public rewardRateForToken;
    mapping(address => uint256) public lastUpdateTimeForToken;
    mapping(address => uint256) public rewardPerTokenStoredForToken;
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaidForToken;
    mapping(address => mapping(address => uint256)) public rewardsForToken;

    event RewardAdded(address rewardToken, uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, address rewardToken, uint256 reward);
    event RewardDenied(address indexed user, address rewardToken, uint256 reward);
    event SmartContractRecorded(address indexed smartContractAddress, address indexed smartContractInitiator);

    modifier updateRewards(address account) {
      for(uint256 i = 0; i < rewardTokens.length; i++ ){
        address rt = rewardTokens[i];
        rewardPerTokenStoredForToken[rt] = rewardPerToken(rt);
        lastUpdateTimeForToken[rt] = lastTimeRewardApplicable(rt);
        if (account != address(0)) {
            rewardsForToken[rt][account] = earned(rt, account);
            userRewardPerTokenPaidForToken[rt][account] = rewardPerTokenStoredForToken[rt];
        }
      }
      _;
    }

    modifier updateReward(address account, address rt){
      rewardPerTokenStoredForToken[rt] = rewardPerToken(rt);
      lastUpdateTimeForToken[rt] = lastTimeRewardApplicable(rt);
      if (account != address(0)) {
          rewardsForToken[rt][account] = earned(rt, account);
          userRewardPerTokenPaidForToken[rt][account] = rewardPerTokenStoredForToken[rt];
      }
      _;
    }

    /** View functions to respect old interface */
    function rewardToken() public view returns(address) {
      return rewardTokens[0];
    }

    function rewardPerToken() public view returns(uint256) {
      return rewardPerToken(rewardTokens[0]);
    }

    function periodFinish() public view returns(uint256) {
      return periodFinishForToken[rewardTokens[0]];
    }

    function rewardRate() public view returns(uint256) {
      return rewardRateForToken[rewardTokens[0]];
    }

    function lastUpdateTime() public view returns(uint256) {
      return lastUpdateTimeForToken[rewardTokens[0]];
    }

    function rewardPerTokenStored() public view returns(uint256) {
      return rewardPerTokenStoredForToken[rewardTokens[0]];
    }

    function userRewardPerTokenPaid(address user) public view returns(uint256) {
      return userRewardPerTokenPaidForToken[rewardTokens[0]][user];
    }

    function rewards(address user) public view returns(uint256) {
      return rewardsForToken[rewardTokens[0]][user];
    }

    // [Hardwork] setting the reward, lpToken, duration, and rewardDistribution for each pool
    constructor(
        address[] memory _rewardTokens,
        address _lpToken,
        uint256 _duration,
        address[] memory _rewardDistribution,
        address _storage,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
      ) public
      ERC20Detailed(_name, _symbol, _decimals)
      IRewardDistributionRecipient(_rewardDistribution)
      Controllable(_storage) // only used for referencing the grey list
    {
        require(_decimals == ERC20Detailed(_lpToken).decimals(), "decimals has to be aligned with the lpToken");
        require(_rewardTokens.length != 0, "should initialize with at least 1 rewardToken");
        rewardTokens = _rewardTokens;
        lpToken = _lpToken;
        duration = _duration;
    }

    function lastTimeRewardApplicable(uint256 i) public view returns (uint256) {
        return lastTimeRewardApplicable(rewardTokens[i]);
    }

    function lastTimeRewardApplicable(address rt) public view returns (uint256) {
        return Math.min(block.timestamp, periodFinishForToken[rt]);
    }

    function rewardPerToken(uint256 i) public view returns (uint256) {
        return rewardPerToken(rewardTokens[i]);
    }

    function rewardPerToken(address rt) public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStoredForToken[rt];
        }
        return
            rewardPerTokenStoredForToken[rt].add(
                lastTimeRewardApplicable(rt)
                    .sub(lastUpdateTimeForToken[rt])
                    .mul(rewardRateForToken[rt])
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(uint256 i, address account) public view returns (uint256) {
        return earned(rewardTokens[i], account);
    }

    function earned(address rt, address account) public view returns (uint256) {
        return
            stakedBalanceOf[account]
                .mul(rewardPerToken(rt).sub(userRewardPerTokenPaidForToken[rt][account]))
                .div(1e18)
                .add(rewardsForToken[rt][account]);
    }

    function stake(uint256 amount) public updateRewards(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        recordSmartContract();
        super._mint(msg.sender, amount); // ERC20 is used as a staking receipt
        stakedBalanceOf[msg.sender] = stakedBalanceOf[msg.sender].add(amount);
        IERC20(lpToken).safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public updateRewards(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        super._burn(msg.sender, amount);
        stakedBalanceOf[msg.sender] = stakedBalanceOf[msg.sender].sub(amount);
        IERC20(lpToken).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(Math.min(stakedBalanceOf[msg.sender], balanceOf(msg.sender)));
        getAllRewards();
    }

    /// A push mechanism for accounts that have not claimed their rewards for a long time.
    /// The implementation is semantically analogous to getReward(), but uses a push pattern
    /// instead of pull pattern.
    function pushAllRewards(address recipient) public updateRewards(recipient) onlyGovernance {
      bool rewardPayout = (!smartContractStakers[recipient] || !IController(controller()).greyList(recipient));
      for(uint256 i = 0 ; i < rewardTokens.length; i++ ){
        uint256 reward = earned(rewardTokens[i], recipient);
        if (reward > 0) {
            rewardsForToken[rewardTokens[i]][recipient] = 0;
            // If it is a normal user and not smart contract,
            // then the requirement will pass
            // If it is a smart contract, then
            // make sure that it is not on our greyList.
            if (rewardPayout) {
                IERC20(rewardTokens[i]).safeTransfer(recipient, reward);
                emit RewardPaid(recipient, rewardTokens[i], reward);
            } else {
                emit RewardDenied(recipient, rewardTokens[i], reward);
            }
        }
      }
    }

    function getAllRewards() public updateRewards(msg.sender) {
      recordSmartContract();
      bool rewardPayout = (!smartContractStakers[msg.sender] || !IController(controller()).greyList(msg.sender));
      for(uint256 i = 0 ; i < rewardTokens.length; i++ ){
        _getRewardAction(rewardTokens[i], rewardPayout);
      }
    }

    function getReward(address rt) public updateReward(msg.sender, rt) {
      recordSmartContract();
      _getRewardAction(
        rt,
        // don't payout if it is a grey listed smart contract
        (!smartContractStakers[msg.sender] || !IController(controller()).greyList(msg.sender))
      );
    }

    function getReward() public {
      getReward(rewardTokens[0]);
    }

    function _getRewardAction(address rt, bool rewardPayout) internal {
      uint256 reward = earned(rt, msg.sender);
      if (reward > 0 && IERC20(rt).balanceOf(address(this)) >= reward ) {
          rewardsForToken[rt][msg.sender] = 0;
          // If it is a normal user and not smart contract,
          // then the requirement will pass
          // If it is a smart contract, then
          // make sure that it is not on our greyList.
          if (rewardPayout) {
              IERC20(rt).safeTransfer(msg.sender, reward);
              emit RewardPaid(msg.sender, rt, reward);
          } else {
              emit RewardDenied(msg.sender, rt, reward);
          }
      }
    }

    function addRewardToken(address rt) public onlyGovernance {
      require(getRewardTokenIndex(rt) == uint256(-1), "Reward token already exists");
      rewardTokens.push(rt);
    }

    function removeRewardToken(address rt) public onlyGovernance {
      uint256 i = getRewardTokenIndex(rt);
      require(i != uint256(-1), "Reward token does not exists");
      require(periodFinishForToken[rewardTokens[i]] < block.timestamp, "Can only remove when the reward period has passed");
      require(rewardTokens.length > 1, "Cannot remove the last reward token");
      uint256 lastIndex = rewardTokens.length - 1;

      // swap
      rewardTokens[i] = rewardTokens[lastIndex];

      // delete last element
      rewardTokens.length--;
    }

    // If the return value is MAX_UINT256, it means that
    // the specified reward token is not in the list
    function getRewardTokenIndex(address rt) public view returns(uint256) {
      for(uint i = 0 ; i < rewardTokens.length ; i++){
        if(rewardTokens[i] == rt)
          return i;
      }
      return uint256(-1);
    }

    function notifyTargetRewardAmount(address _rewardToken, uint256 reward)
        public
        onlyRewardDistribution
        updateRewards(address(0))
    {
        // overflow fix according to https://sips.synthetix.io/sips/sip-77
        require(reward < uint(-1) / 1e18, "the notified reward cannot invoke multiplication overflow");

        uint256 i = getRewardTokenIndex(_rewardToken);
        require(i != uint256(-1), "rewardTokenIndex not found");

        if (block.timestamp >= periodFinishForToken[_rewardToken]) {
            rewardRateForToken[_rewardToken] = reward.div(duration);
        } else {
            uint256 remaining = periodFinishForToken[_rewardToken].sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRateForToken[_rewardToken]);
            rewardRateForToken[_rewardToken] = reward.add(leftover).div(duration);
        }
        lastUpdateTimeForToken[_rewardToken] = block.timestamp;
        periodFinishForToken[_rewardToken] = block.timestamp.add(duration);
        emit RewardAdded(_rewardToken, reward);
    }

    function notifyRewardAmount(uint256 reward)
        external
        onlyRewardDistribution
        updateRewards(address(0))
    {
      notifyTargetRewardAmount(rewardTokens[0], reward);
    }

    // Harvest Smart Contract recording
    function recordSmartContract() internal {
      if( tx.origin != msg.sender ) {
        smartContractStakers[msg.sender] = true;
        emit SmartContractRecorded(msg.sender, tx.origin);
      }
    }

}
