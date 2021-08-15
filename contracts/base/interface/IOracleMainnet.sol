pragma solidity 0.5.16;

interface IOracleMainnet {
  function getPrice(address token) external view returns (uint256);
}
