pragma solidity 0.5.16;

interface ICurveDeposit_3token_underlying {
  function get_virtual_price() external view returns (uint);
  function add_liquidity(
    uint256[3] calldata amounts,
    uint256 min_mint_amount,
    bool use_underlying
  ) external;
  function remove_liquidity_imbalance(
    uint256[3] calldata amounts,
    uint256 max_burn_amount,
    bool use_underlying
  ) external;
  function remove_liquidity(
    uint256 _amount,
    uint256[3] calldata amounts,
    bool use_underlying
  ) external;
  function exchange(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function exchange_underlying(
    int128 from, int128 to, uint256 _from_amount, uint256 _min_to_amount
  ) external;
  function calc_token_amount(
    uint256[3] calldata amounts,
    bool deposit
  ) external view returns(uint);
}
