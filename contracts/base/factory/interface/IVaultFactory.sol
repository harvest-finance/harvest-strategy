pragma solidity 0.5.16;

interface IVaultFactory {
  function deploy(address _storage, address _underlying) external returns (address);
  function info(address vault) external view returns(address Underlying, address NewVault);
}
