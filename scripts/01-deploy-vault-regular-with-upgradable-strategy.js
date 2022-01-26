const prompt = require('prompt');
const hre = require("hardhat");
const { type2Transaction } = require('./utils.js');

function cleanupObj(d) {
  for (let i = 0; i < 10; i++) delete d[String(i)];
  delete d["vaultType"];
  return d;
}

async function main() {
  console.log("Regular vault deployment with upgradable strategy.");
  console.log("> Prerequisite: deploy upgradable strategy implementation");
  console.log("Specify a unique ID (for the JSON), vault's underlying token address, and upgradable strategy implementation address");
  prompt.start();
  const addresses = require("../test/test-config.js");
  const MegaFactory = artifacts.require("MegaFactory");

  const {id, underlying, strategyName} = await prompt.get(['id', 'underlying', 'strategyName']);
  const factory = await MegaFactory.at(addresses.Factory.MegaFactory);

  const StrategyImpl = artifacts.require(strategyName);
  const impl = await type2Transaction(StrategyImpl.new);

  console.log("Implementation deployed at:", impl.creates);

  await type2Transaction(factory.createRegularVaultUsingUpgradableStrategy, id, underlying, impl.creates)

  const deployment = cleanupObj(await factory.completedDeployments(id));
  console.log("======");
  console.log(`${id}: ${JSON.stringify(deployment, null, 2)}`);
  console.log("======");

  console.log("Deployment complete. Add the JSON above to `harvest-api` (https://github.com/harvest-finance/harvest-api/blob/master/data/mainnet/addresses.json) repo and add entries to `tokens.js` and `pools.js`.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
