const prompt = require('prompt');
const hre = require("hardhat");
const { type2Transaction } = require('./utils.js');

async function main() {
  console.log("Upgradable strategy deployment.");
  console.log("Specify a the vault address, and the strategy implementation's name");
  prompt.start();
  const addresses = require("../test/test-config.js");

  const {id, vaultAddr, strategyName} = await prompt.get(['vaultAddr', 'strategyName']);

  const StrategyImpl = artifacts.require(strategyName);
  const impl = await type2Transaction(StrategyImpl.new);

  console.log("Implementation deployed at:", impl.creates);

  const StrategyProxy = artifacts.require('StrategyProxy');
  const proxy = await type2Transaction(StrategyProxy.new, impl.creates);

  console.log("Proxy deployed at:", proxy.creates);

  const strategy = await StrategyImpl.at(proxy.creates);
  await type2Transaction(strategy.initializeStrategy, addresses.Storage, vaultAddr);

  console.log("Deployment complete. New strategy deployed and initialised at", proxy.creates);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
