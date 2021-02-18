pragma solidity 0.5.16;

interface ICurveSTETHDeposit {
    function get_virtual_price() external view returns (uint);
    function add_liquidity(
        uint256[2] calldata amounts,
        uint256 min_mint_amount
    ) external payable returns (uint256);
}
