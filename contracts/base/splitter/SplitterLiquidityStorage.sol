pragma solidity 0.5.16;

import "./SplitterStorage.sol";

contract SplitterLiquidityStorage is SplitterStorage {

  bytes32 internal constant _LIQUIDITY_LOAN_CURRENT_SLOT = 0x43f4f80901a31b10a1c754f4b057fbe7b4f994e49d48c4b673e343a6ee65d97e;
  bytes32 internal constant _LIQUIDITY_LOAN_TARGET_SLOT = 0xc24e073228ad0883559cda19937ae5ff046a5a729089b5c48863cadec04f0a31;
  bytes32 internal constant _LIQUIDITY_RECIPIENT_SLOT = 0x5a9ac49e47daf11cc7c0c2af565a15107ea67c37329bf6b26f8b61145e659317;

  constructor() SplitterStorage() public {
    assert(_LIQUIDITY_LOAN_CURRENT_SLOT == bytes32(uint256(keccak256("eip1967.splitterLiquidityStorage.liquidityLoanCurrent")) - 1));
    assert(_LIQUIDITY_LOAN_TARGET_SLOT == bytes32(uint256(keccak256("eip1967.splitterLiquidityStorage.liquidityLoanTarget")) - 1));
    assert(_LIQUIDITY_RECIPIENT_SLOT == bytes32(uint256(keccak256("eip1967.splitterLiquidityStorage.liquidityRecipient")) - 1));
  }

  function _setLiquidityLoanCurrent(uint256 _value) internal {
    setUint256(_LIQUIDITY_LOAN_CURRENT_SLOT, _value);
  }

  function liquidityLoanCurrent() public view returns (uint256) {
    return getUint256(_LIQUIDITY_LOAN_CURRENT_SLOT);
  }


  function _setLiquidityLoanTarget(uint256 _value) internal {
    setUint256(_LIQUIDITY_LOAN_TARGET_SLOT, _value);
  }

  function liquidityLoanTarget() public view returns (uint256) {
    return getUint256(_LIQUIDITY_LOAN_TARGET_SLOT);
  }

  function _setLiquidityRecipient(address _address) internal {
    setAddress(_LIQUIDITY_RECIPIENT_SLOT, _address);
  }

  function liquidityRecipient() public view returns (address) {
    return getAddress(_LIQUIDITY_RECIPIENT_SLOT);
  }

  function setAddress(bytes32 slot, address _address) internal {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      sstore(slot, _address)
    }
  }

  function setUint256(bytes32 slot, uint256 _value) internal {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      sstore(slot, _value)
    }
  }

  function getAddress(bytes32 slot) internal view returns (address str) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      str := sload(slot)
    }
  }

  function getUint256(bytes32 slot) internal view returns (uint256 str) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      str := sload(slot)
    }
  }
}
