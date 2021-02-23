const makeVault = require("./make-vault.js");
const addresses = require("../test-config.js");
const IController = artifacts.require("IController");
const IFeeRewardForwarder = artifacts.require("IFeeRewardForwarder");

const ILiquidatorRegistry = artifacts.require("ILiquidatorRegistry");
const INoMintRewardPool = artifacts.require("INoMintRewardPool");

const IVault = artifacts.require("IVault");
const Utils = require("./Utils.js");

async function impersonates(targetAccounts){
  console.log("Impersonating...");
  for(i = 0; i < targetAccounts.length ; i++){
    console.log(targetAccounts[i]);
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [
        targetAccounts[i]
      ]
    });
  }
}

async function setupCoreProtocol(config) {
  // Set vault (or Deploy new vault), underlying, underlying Whale,
  // amount the underlying whale should send to farmers
  if(config.existingVaultAddress != null){
    vault = await IVault.at(config.existingVaultAddress);
    console.log("Fetching Vault at: ", vault.address);
  } else {
    const implAddress = config.vaultImplementationOverride || addresses.VaultImplementationV1;
    vault = await makeVault(implAddress, addresses.Storage, config.underlying.address, 100, 100, {
      from: config.governance,
    });
    console.log("New Vault Deployed: ", vault.address);
  }

  let rewardPool = null;

  // if reward pool is required, then deploy it
  if(config.rewardPool != null && config.existingRewardPoolAddress == null) {
    const NoMintRewardPool = artifacts.require("NoMintRewardPool");
    console.log("reward pool needs to be deployed");
    rewardPool = await NoMintRewardPool.new(
      addresses.FARM,
      vault.address,
      64800,
      config.governance,
      addresses.Storage,
      "0x0000000000000000000000000000000000000000",
      "0x0000000000000000000000000000000000000000",
      {from: config.governance }
    );
    console.log("New Reward Pool deployed: ", rewardPool.address);
  } else if(config.existingRewardPoolAddress != null) {
    const NoMintRewardPool = artifacts.require("NoMintRewardPool");
    rewardPool = await NoMintRewardPool.at(config.existingRewardPoolAddress);
    console.log("Fetching Reward Pool deployed: ", rewardPool.address);
  }


  let universalLiquidatorRegistry = await ILiquidatorRegistry.at(addresses.UniversalLiquidatorRegistry);

  // set liquidation paths
  if(config.liquidation) {
    for( token in config.liquidation) {
      for (dex in config.liquidation[token]) {
        await universalLiquidatorRegistry.setPath(
          web3.utils.keccak256(dex),
          config.liquidation[token][dex][0],
          config.liquidation[token][dex][config.liquidation[token][dex].length - 1],
          config.liquidation[token][dex],
          {from: config.governance }
        );
      }
    }
  }

  // default arguments are storage and vault addresses
  config.strategyArgs = config.strategyArgs || [
    addresses.Storage,
    vault.address
  ];

  for(i = 0; i < config.strategyArgs.length ; i++){
    if(config.strategyArgs[i] == "vaultAddr") {
      config.strategyArgs[i] = vault.address;
    } else if(config.strategyArgs[i] == "poolAddr" ){
      config.strategyArgs[i] = rewardPool.address;
    } else if(config.strategyArgs[i] == "universalLiquidatorRegistryAddr"){
      config.strategyArgs[i] = universalLiquidatorRegistry.address;
    }
  }

  if (config.strategyArtifactIsUpgradable == null) {
    strategy = await config.strategyArtifact.new(
      ...config.strategyArgs,
      { from: config.governance }
    );
  } else {
    const strategyImpl = await config.strategyArtifact.new();
    const StrategyProxy = artifacts.require("StrategyProxy");

    const strategyProxy = await StrategyProxy.new(strategyImpl.address);
    strategy = await config.strategyArtifact.at(strategyProxy.address);
    await strategy.initializeStrategy(
      ...config.strategyArgs,
      { from: config.governance }
    );
  }

  console.log("Strategy Deployed: ", strategy.address);

  if (config.feeRewardForwarderLiquidationPath) {
    // legacy path support
    const path = config.feeRewardForwarderLiquidationPath;
    await universalLiquidatorRegistry.setPath(
      web3.utils.keccak256("uni"),
      path[0],
      path[path.length - 1],
      path
    );
  }

  controller = await IController.at(addresses.Controller);

  if (config.announceStrategy === true) {
    // Announce switch, time pass, switch to strategy
    await vault.announceStrategyUpdate(strategy.address, { from: config.governance });
    console.log("Strategy switch announced. Waiting...");
    await Utils.waitHours(13);
    await vault.setStrategy(strategy.address, { from: config.governance });
    await vault.setVaultFractionToInvest(100, 100, { from: config.governance });
    console.log("Strategy switch completed.");
  } else {
    await controller.addVaultAndStrategy(
      vault.address,
      strategy.address,
      { from: config.governance }
    );
    console.log("Strategy and vault added to Controller.");
  }

  return [controller, vault, strategy, rewardPool];
}

async function depositVault(_farmer, _underlying, _vault, _amount) {
  await _underlying.approve(_vault.address, _amount, { from: _farmer });
  await _vault.deposit(_amount, { from: _farmer });
}

module.exports = {
  impersonates,
  setupCoreProtocol,
  depositVault,
};
