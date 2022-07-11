pragma solidity 0.5.16;

interface ICurveDeposit_2token {
  function get_virtual_price() external view returns (uint);
  function add_liquidity(
    uint256[2] calldata amounts,
    uint256 min_mint_amount
  ) external payable;
  function remove_liquidity_imbalance(
    uint256[2] calldata amounts,
    uint256 max_burn_amount
  ) external;
  function remove_liquidity(
    uint256 _amount,
    uint256[2] calldata amounts
  ) external;
  function exchange(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external payable;
  function calc_token_amount(
    uint256[2] calldata amounts,
    bool deposit
  ) external view returns(uint);
  function get_dy(
    int128 i,
    int128 j,
    uint256 dx
  ) external view returns(uint256);
}
