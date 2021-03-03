pragma solidity 0.5.16;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../strategies/aave/AaveInteractor.sol";
import "../../strategies/sushi/interface/SushiBar.sol";

contract SushiHODLWallet is Ownable, AaveInteractor {

  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  uint256 public totalDeposited;
  address public sushi;
  address public sushiDistributor;
  address public sushiBar;
  address public recipient;
  mapping(address => bool) public unsalvageable;

  modifier onlySushiDistributor() {
    require(msg.sender == sushiDistributor, "Only sushi distributor");
    _;
  }

  constructor(address _sushiDistributor,
    address _sushi,
    address _sushiBar,
    address _recipient,
    address _lendingPoolProvider,
    address _protocolDataProvider
  ) AaveInteractor(_sushiBar, _lendingPoolProvider, _protocolDataProvider) public {
    require(_sushiDistributor != address(0), "invalid sushi distributor");
    sushiDistributor = _sushiDistributor;
    require(_sushi != address(0), "invalid sushi");
    sushi = _sushi;
    require(_sushiBar != address(0), "invalid sushi bar");
    sushiBar = _sushiBar;
    require(_recipient != address(0), "invalid recipient");
    recipient = _recipient;
    unsalvageable[_sushi] = true;
    unsalvageable[_sushiBar] = true;
    unsalvageable[aToken()] = true;
  }

  /**
  * Transfers SUSHI in and records the amount.
  */
  function start(uint256 _totalDeposited) external onlySushiDistributor {
    totalDeposited = totalDeposited.add(_totalDeposited);
    // get tokens in
    IERC20(sushi).safeTransferFrom(msg.sender, address(this), _totalDeposited);
  }

  /**
  * Deposits the indicated amount of xsushi to aave.
  */
  function toAave(uint256 _amount) public onlyOwner {
    _aaveDeposit(_amount);
  }

  /**
  * Withdraws the indicated amount of xsushi from aave.
  */
  function fromAave(uint256 _amount) public onlyOwner {
    _aaveWithdraw(_amount);
  }

  /**
  * Deposits the specified amount to sushiBar.
  */
  function toSushiBar(uint256 _amount) public onlyOwner {
    IERC20(sushi).safeApprove(sushiBar, 0);
    IERC20(sushi).safeApprove(sushiBar, _amount);
    SushiBar(sushiBar).enter(_amount);
  }

  /**
  * Withdraws the specified amount from sushiBar.
  */
  function fromSushiBar(uint256 _amount) public onlyOwner {
    SushiBar(sushiBar).leave(_amount);
  }

  /**
  * Sends the specified amount of sushi to the recipient.
  */
  function withdraw(uint256 _amount) public onlyOwner {
    IERC20(sushi).transfer(recipient, _amount);
  }

  /**
  * Wraps the specified amount of sushi to xsushi, and deposits the
  * specified amount to aave.
  */
  function wrap(uint256 _toSushiBar, uint256 _toAave) public onlyOwner {
    uint256 balance = IERC20(sushi).balanceOf(address(this));
    uint256 wrapToSushiBar = Math.min(balance, _toSushiBar);
    if (balance > 0) {
      toSushiBar(wrapToSushiBar);
    }

    uint256 xBalance = IERC20(sushiBar).balanceOf(address(this));
    uint256 wrapToAave = Math.min(xBalance, _toAave);
    if (wrapToAave > 0) {
      toAave(wrapToAave);
    }
  }

  /**
  * Withdraws the specified amount from aave, and unwraps the specified
  * xsushi to sushi.
  */
  function unwrap(uint256 _fromSushiBar, uint256 _fromAave) public onlyOwner {
    // max check is done inside aave interactor
    if (_fromAave > 0) {
      fromAave(_fromAave);
    }

    uint256 xBalance = IERC20(sushiBar).balanceOf(address(this));
    uint256 unwrapFromSushiBar = Math.min(xBalance, _fromSushiBar);
    if (unwrapFromSushiBar > 0) {
      fromSushiBar(unwrapFromSushiBar);
    }
  }

  /**
  * Administration method. Sets new recipient.
  */
  function setRecipient(address _recipient) public onlyOwner {
    require(_recipient != address(0), "invalid recipient");
    recipient = _recipient;
  }

  /**
  * Salvages tokens other than atokens, sushi and xsushi. 
  */
  function salvage(address _recipient, address _token, uint256 _amount) public onlyOwner {
    require(!unsalvageable[_token], "the token cannot be salvaged");
    IERC20(_token).safeTransfer(_recipient, _amount);
  }

  /**
  * Salvages ETH.
  */
  function salvageEth(address payable _recipient, uint256 _amount) public onlyOwner {
    _recipient.transfer(_amount);
  }
}
