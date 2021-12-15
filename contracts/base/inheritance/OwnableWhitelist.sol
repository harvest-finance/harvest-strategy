pragma solidity 0.5.16;

import "@openzeppelin/contracts/ownership/Ownable.sol";

contract OwnableWhitelist is Ownable {
  mapping (address => bool) public whitelist;

  modifier onlyWhitelisted() {
    require(whitelist[msg.sender] || msg.sender == owner(), "not allowed");
    _;
  }

  function setWhitelist(address target, bool isWhitelisted) public onlyOwner {
    whitelist[target] = isWhitelisted;
  }
}
