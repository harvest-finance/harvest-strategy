pragma solidity 0.5.16;

interface ICurveAAVEDeposit {
    function get_virtual_price() external view returns (uint);
    function add_liquidity(uint256[3] calldata _amounts, uint256 _min_mint_amount, bool _use_underlying) external returns (uint256);
}
