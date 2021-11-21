pragma solidity 0.5.16;

import "../../VaultProxy.sol";
import "../../interface/IVault.sol";
import "../interface/IVaultFactory.sol";
import "../../inheritance/OwnableWhitelist.sol";

contract RegularVaultFactory is OwnableWhitelist, IVaultFactory {
  address public vaultImplementation = 0x9B3bE0cc5dD26fd0254088d03D8206792715588B;
  address public lastDeployedAddress = address(0);

  function deploy(address _storage, address underlying) external onlyWhitelisted returns (address) {
    lastDeployedAddress = address(new VaultProxy(vaultImplementation));
    IVault(lastDeployedAddress).initializeVault(
      _storage,
      underlying,
      9700,
      10000
    );

    return lastDeployedAddress;
  }

  function changeDefaultImplementation(address newImplementation) external onlyOwner {
    require(newImplementation != address(0), "Must be set");
    vaultImplementation = newImplementation;
  }

  function info(address vault) external view returns(address Underlying, address NewVault) {
    Underlying = IVault(vault).underlying();
    NewVault = vault;
  }
}
