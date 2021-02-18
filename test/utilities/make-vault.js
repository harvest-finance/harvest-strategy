const Vault = artifacts.require("IVault");
const VaultProxy = artifacts.require("VaultProxy");

module.exports = async function(implementationAddress, ...args) {
  const fromParameter = args[args.length - 1]; // corresponds to {from: governance}
  const vaultAsProxy = await VaultProxy.new(implementationAddress, fromParameter);
  const vault = await Vault.at(vaultAsProxy.address);
  await vault.initializeVault(...args);
  return vault;
};
