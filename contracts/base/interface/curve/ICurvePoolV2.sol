pragma solidity 0.5.16;

interface ICurvePoolV2 {
  function exchange(
    uint256 from, uint256 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function exchange_underlying(
    uint256 from, uint256 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
}
