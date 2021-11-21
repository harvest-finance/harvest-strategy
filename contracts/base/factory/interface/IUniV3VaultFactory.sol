pragma solidity 0.5.16;

interface IUniV3VaultFactory {
  function deploy(address _storage, uint256 univ3PoolId) external returns (address vault);
  function info(address vault) external view returns(address[] memory Underlying, address NewVault, address DataContract, uint256 FeeAmount, uint256 PosId);
}
