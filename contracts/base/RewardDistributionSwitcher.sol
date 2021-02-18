pragma solidity 0.5.16;

import "./inheritance/Controllable.sol";
import "./interface/INoMintRewardPool.sol";

contract RewardDistributionSwitcher is Controllable {

  mapping (address => bool) switchingAllowed;

  constructor(address _storage) public Controllable(_storage){}

  function returnOwnership(address poolAddr) public onlyGovernance {
    INoMintRewardPool(poolAddr).transferOwnership(governance());
  }

  function enableSwitchers(address[] memory switchers) public onlyGovernance {
    for(uint256 i = 0; i < switchers.length; i++){
      switchingAllowed[switchers[i]] = true;
    }
  }

  function setSwitcher(address switcher, bool allowed) public onlyGovernance {
    switchingAllowed[switcher] = allowed;
  }


  function setPoolRewardDistribution(address poolAddr, address newRewardDistributor) public {
    require(msg.sender == governance() || switchingAllowed[msg.sender], "msg.sender not allowed to switch");

    INoMintRewardPool(poolAddr).setRewardDistribution(newRewardDistributor);
  }

}
