const prompt = require('prompt');
const hre = require("hardhat");
const { type2Transaction } = require('./utils.js');

function cleanupObj(d) {
  for (let i = 0; i < 10; i++) delete d[String(i)];
  delete d["vaultType"];
  return d;
}

async function main() {
  console.log("Regular vault deployment (no strategy).\nSpecify a unique ID (for the JSON) and the vault's underlying token address");
  prompt.start();
  const addresses = require("../test/test-config.js");
  const MegaFactory = artifacts.require("MegaFactory");

  const {id, underlying} = await prompt.get(['id', 'underlying']);
  const factory = await MegaFactory.at(addresses.Factory.MegaFactory);

  await type2Transaction(factory.createRegularVault, id, underlying);

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
