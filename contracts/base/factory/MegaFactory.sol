pragma solidity 0.5.16;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./interface/IStrategyFactory.sol";
import "./interface/IVaultFactory.sol";
import "./interface/IPoolFactory.sol";
import "./interface/IUniV3VaultFactory.sol";

import "../interface/IVault.sol";
import "../inheritance/Governable.sol";

contract MegaFactory is Ownable {

  enum VaultType {
    None,
    Regular,
    UniV3
  }

  enum StrategyType {
    None,
    Upgradable
  }

  address public potPoolFactory;
  mapping(uint256 => address) public vaultFactories;
  mapping(uint256 => address) public strategyFactories;

  struct CompletedDeployment {
    VaultType vaultType;
    address Underlying;
    address NewVault;
    address NewStrategy;
    address NewPool;
  }

  event DeploymentCompleted(string id);

  mapping (string => CompletedDeployment) public completedDeployments;
  mapping (address => bool) public authorizedDeployers;

  address public multisig;
  address public actualStorage;

  /* methods to make compatible with Storage */
  function governance() external view returns (address) {
    return address(this); // fake governance
  }

  function isGovernance(address addr) external view returns (bool) {
    return addr == address(this); // fake governance
  }

  function isController(address addr) external view returns (bool) {
    return addr == address(this); // fake controller
  }

  modifier onlyAuthorizedDeployer(string memory id) {
    require(completedDeployments[id].vaultType == VaultType.None, "cannot reuse id");
    require(authorizedDeployers[msg.sender], "unauthorized deployer");
    _;
    emit DeploymentCompleted(id);
  }

  constructor(address _storage, address _multisig) public {
    multisig = _multisig;
    actualStorage = _storage;
    setAuthorization(owner(), true);
    setAuthorization(multisig, true);
  }

  function setAuthorization(address userAddress, bool isDeployer) public onlyOwner {
    authorizedDeployers[userAddress] = isDeployer;
  }

  function setVaultFactory(uint256 vaultType, address factoryAddress) external onlyOwner {
    vaultFactories[vaultType] = factoryAddress;
  }

  function setStrategyFactory(uint256 strategyType, address factoryAddress) external onlyOwner {
    strategyFactories[strategyType] = factoryAddress;
  }

  function setPotPoolFactory(address factoryAddress) external onlyOwner {
    potPoolFactory = factoryAddress;
  }

  function createRegularVault(string calldata id, address underlying) external onlyAuthorizedDeployer(id) {
    address vault = IVaultFactory(vaultFactories[uint256(VaultType.Regular)]).deploy(
     actualStorage,
     underlying
    );

    completedDeployments[id] = CompletedDeployment(
      VaultType.Regular,
      underlying,
      vault,
      address(0),
      IPoolFactory(potPoolFactory).deploy(actualStorage, vault)
    );
  }

  function createRegularVaultUsingUpgradableStrategy(string calldata id, address underlying, address strategyImplementation) external onlyAuthorizedDeployer(id) {
    address vault = IVaultFactory(vaultFactories[uint256(VaultType.Regular)]).deploy(
     address(this), // using this as initial storage, then switching to actualStorage
     underlying
    );

    address strategy = IStrategyFactory(strategyFactories[uint256(StrategyType.Upgradable)]).deploy(actualStorage, vault, strategyImplementation);
    IVault(vault).setStrategy(strategy);
    Governable(vault).setStorage(actualStorage);

    completedDeployments[id] = CompletedDeployment(
      VaultType.Regular,
      underlying,
      vault,
      strategy,
      IPoolFactory(potPoolFactory).deploy(actualStorage, vault)
    );
  }

  function createUniV3Vault(string calldata id, uint256 uniV3PoolId) external onlyAuthorizedDeployer(id) {
    address vault = IUniV3VaultFactory(vaultFactories[uint256(VaultType.UniV3)]).deploy(
      actualStorage,
      uniV3PoolId
    );

    completedDeployments[id] = CompletedDeployment(
      VaultType.UniV3,
      address(0),
      vault,
      address(0),
      IPoolFactory(potPoolFactory).deploy(actualStorage, vault)
    );
  }
}
