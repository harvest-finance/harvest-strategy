pragma solidity 0.5.16;

import "./SplitterLiquidityStorage.sol";
import "./SplitterStrategy.sol";
import "./ILiquidityRecipient.sol";

contract LiquidityProvisionSplitter is SplitterStrategy, SplitterLiquidityStorage {

  uint256 constant public tenWeth = 10_000000_000000_000000;

  constructor() public {}

  function initLiquidityProvisionSplitter(
    address _storage,
    address _vault,
    address _strategyWhitelist, // a contract where all whitelisted strategies are persisted (across upgrades)
    address _splitterConfig     // a data contract where the strategy configuration is persisted (across upgrades)
  ) public initializer {
    SplitterStrategy.initSplitter(_storage, _vault, _strategyWhitelist, _splitterConfig);
  }

  /*
  * Returns the total invested amount. Includes its own balance (in case it isn't invested yet),
  * and it includes the value that was borrowed for liquidity provisioning.
  */
  function investedUnderlyingBalance() public view returns (uint256) {
    return liquidityLoanCurrent().add(SplitterStrategy.investedUnderlyingBalance());
  }

  /**
  * Provides a loan to the liquidity strategy. Sends in funds to fill out the loan target amount,
  * if they are available.
  */
  function provideLoan() public onlyGovernance {
    if (
      liquidityLoanCurrent() < liquidityLoanTarget()
      && IERC20(underlying()).balanceOf(address(this)) > 0
      && liquidityRecipient() != address(0)
    ) {
      uint256 diff = Math.min(
        liquidityLoanTarget().sub(liquidityLoanCurrent()),
        IERC20(underlying()).balanceOf(address(this))
      );
      IERC20(underlying()).safeApprove(liquidityRecipient(), 0);
      IERC20(underlying()).safeApprove(liquidityRecipient(), diff);
      // use the pull pattern so that this fails if the contract is not set properly
      ILiquidityRecipient(liquidityRecipient()).takeLoan(diff);
      _setLiquidityLoanCurrent(liquidityLoanCurrent().add(diff));
    }
  }


  /**
  * Settles a loan amount by forcing withdrawal inside the liquidity strategy, and then transferring
  * the funds back to this strategy. This way, the loan can be settled partially, or completely.
  * The method can be invoked only by EOAs to avoid market manipulation, and only by the governance
  * unless there is not more than 10 WETH left in this strategy.
  */
  function settleLoan(uint256 amount) public {
    require(
    // the only funds in are in the loan, other than 10 WETH
      investedUnderlyingBalance() <= liquidityLoanCurrent().add(tenWeth)
      // or the governance wants this to happen
      || msg.sender == governance(),
      "Buffer exists and the caller is not governance"
    );
    // market manipulation prevention
    require(tx.origin == msg.sender, "no smart contracts");

    if (liquidityLoanCurrent() == 0) {
      return;
    }

    ILiquidityRecipient(liquidityRecipient()).settleLoan();
    IERC20(underlying()).safeTransferFrom(liquidityRecipient(), address(this), amount);
    _setLiquidityLoanCurrent(liquidityLoanCurrent().sub(amount));
    if (liquidityLoanCurrent() == 0) {
      ILiquidityRecipient(liquidityRecipient()).wethOverdraft();
    }
  }

  function setLiquidityRecipient(address recipient) public onlyGovernance {
    require(liquidityRecipient() == address(0) || liquidityLoanCurrent() == 0,
      "Liquidity recipient was already set, and has a loan");
    _setLiquidityRecipient(recipient);
  }

  function setLiquidityLoanTarget(uint256 target) public onlyGovernance {
    _setLiquidityLoanTarget(target);
  }
}
