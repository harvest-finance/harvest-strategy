pragma solidity 0.5.16;

interface IPoolFactory {
  function deploy(address _storage, address _vault) external returns (address);
}
