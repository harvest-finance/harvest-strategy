pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IsApe {
    function wrap(uint256 amountTokenIn) external;
    function unwrap(uint256 amountShares) external;
}