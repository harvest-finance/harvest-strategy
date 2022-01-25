const prompt = require('prompt');
const hre = require("hardhat");
const { web3 } = require("hardhat");
const { type2Transaction } = require('./utils.js');

function cleanupObj(d) {
  for (let i = 0; i < 10; i++) delete d[String(i)];
  delete d["vaultType"];
  return d;
}

async function main() {
  const addresses = require("../test/test-config.js");
  console.log("Uniswap V3 vault deployment.");
  console.log(`Prerequisite: create a position token using Uniswap V3, and SEND it to ${addresses.Factory.UniV3VaultFactory}.`);
  console.log(`For this, go to https://etherscan.io/address/0xC36442b4a4522E871399CD717aBDD847Ab11FE88#writeProxyContract and do transferFrom(yourAddress, ${addresses.Factory.UniV3VaultFactory}, <position-number>)`)
  console.log("Specify a unique ID (for the JSON) and position token's number");
  prompt.start();
  const MegaFactory = artifacts.require("MegaFactory");
  const IUniV3VaultFactory = artifacts.require("IUniV3VaultFactory");

  const {id, positionTokenNumber} = await prompt.get(['id', 'positionTokenNumber']);
  const factory = await MegaFactory.at(addresses.Factory.MegaFactory);

  await type2Transaction(factory.createUniV3Vault, id, positionTokenNumber);

  const deployment = cleanupObj(await factory.completedDeployments(id));
  const uniV3VaultFactory = await IUniV3VaultFactory.at(addresses.Factory.UniV3VaultFactory);
  const info = await uniV3VaultFactory.info(deployment.NewVault);
  deployment.Underlying = info.Underlying;
  deployment.DataContract = info.DataContract;
  deployment.FeeAmount = web3.utils.hexToNumber(info.FeeAmount);
  deployment.PosId = [web3.utils.hexToNumber(info.PosId)];

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
