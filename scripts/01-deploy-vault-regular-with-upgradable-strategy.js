const prompt = require('prompt');
const hre = require("hardhat");

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

  const {id, underlying, strategyImpl} = await prompt.get(['id', 'underlying', 'strategyImpl']);
  const factory = await MegaFactory.at(addresses.Factory.MegaFactory);

  await factory.createRegularVaultUsingUpgradableStrategy(
    id, underlying, strategyImpl
  );

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
