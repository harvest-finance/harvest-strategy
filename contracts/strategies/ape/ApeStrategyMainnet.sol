pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interface/IsApe.sol";

import "../../base/StrategyBase.sol";

/**
* This strategy for ApeCoin
*
*/
contract ApeStrategyMainnet is IStrategy, RewardTokenProfitNotifier {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public underlying;
    address public vault;

    address public sApe = address(0x47BA20283Be4d72D4AFB1862994F4203551539C5);
    address public apeCoin = address(0x4d224452801ACEd8B2F0aebE155379bb5D594381);

    // These tokens cannot be claimed by the controller
    mapping (address => bool) public unsalvagableTokens;

    modifier restricted() {
        require(msg.sender == vault || msg.sender == address(controller()) || msg.sender == address(governance()),
            "The sender has to be the controller or vault or governance");
        _;
    }

    constructor(
        address _storage,
        address _vault
    ) RewardTokenProfitNotifier(_storage, apeCoin) public {
        underlying = IERC20(apeCoin);
        vault = _vault;

        // set these tokens to be not salvagable
        unsalvagableTokens[apeCoin] = true;
        unsalvagableTokens[sApe] = true;
    }

    function depositArbCheck() public view returns(bool) {
        return true;
    }

    /*
    * We invest ApeCoin in sAPE, after sAPE stake in ApeCoinStacking.
    *
    */
    function doHardWork() public restricted {
        investAllUnderlying();
    }

    function investAllUnderlying() public restricted {
        uint256 underlyingBalance = underlying.balanceOf(address(this));
        if (underlyingBalance > 0) {
            underlying.safeApprove(sApe, 0);
            underlying.safeApprove(sApe, underlyingBalance);
            IsApe(sApe).wrap(underlyingBalance);
        }
    }

    /*
    * Withdraw to vault
    *
    */
    function withdrawToVault(uint256 amount) public restricted {
        uint256 balanceBefore = underlying.balanceOf(address(this));
        IsApe(sApe).unwrap(amount);
        uint256 balanceAfter = underlying.balanceOf(address(this));
        underlying.safeTransfer(vault, balanceAfter.sub(balanceBefore));
    }

    /*
    * Withdraw all to vault
    *
    */
    function withdrawAllToVault() external restricted {
        withdrawAll();
        underlying.safeTransfer(vault, underlying.balanceOf(address(this)));
    }

    function withdrawAll() internal {
        uint256 balance = IERC20(sApe).balanceOf(address(this));

        IsApe(sApe).unwrap(balance);
    }

    /**
    * Salvages a token.
    *
    */
    function salvage(address recipient, address token, uint256 amount) public onlyGovernance {
        // To make sure that governance cannot come in and take away the coins
        require(!unsalvagableTokens[token], "token is defined as not salvagable");
        IERC20(token).safeTransfer(recipient, amount);
    }

    /**
    * Investing all underlying.
    *
    */
    function investedUnderlyingBalance() public view returns (uint256) {
        return IERC20(sApe).balanceOf(address(this)).add(
            IERC20(underlying).balanceOf(address(this))
        );
    }
}