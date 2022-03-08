# Factory Scripts

The scripts allow for a whitelisted party to deploy components of Harvest, such as vaults, pools, and strategies.
Important:
1. Set gas limit to VERY high (~9,000,000)
2. Deployments are pretty expensive: please make sure there is enough Ether (1 ETH, or more for one deployment).
3. Always simulate the transaction first by appending the flag `--network hardhat` (or omitting `--network`)
4. Once simulation is successful, use the mainnet flag: `--network mainnet`
5. Take prerequisites into account (such as, creating a position token for Uniswap V3)

Latest factory addresses are located in `./test/test-config.js`, under `Factory`.

### Regular vault (with upgradable strategy)

Deploying a new vault with the standard reward PotPool, using an upgradable strategy implementation (that was deployed earlier):

```
npx hardhat run ./scripts/01-deploy-vault-regular-with-upgradable-strategy.js --network hardhat
Regular vault deployment with upgradable strategy.
> Prerequisite: deploy upgradable strategy implementation
Specify a unique ID (for the JSON), vault's underlying token address, and upgradable strategy implementation address
prompt: id:  test_YEL_WETH
prompt: underlying:  0xc83cE8612164eF7A13d17DDea4271DD8e8EEbE5d
prompt: strategyImpl:  0xBa6b43ae8Ea74a5D7F4e65904aAf80bFB1Bc59CB
======
test_YEL_WETH: {
  "Underlying": "0xc83cE8612164eF7A13d17DDea4271DD8e8EEbE5d",
  "NewVault": "0xd1c9CE4C3D87B2B9dDc500F6f47E65FB7d426Ac2",
  "NewStrategy": "0x908B743A405F23Ea5877C14E32d76B1B7A97369D",
  "NewPool": "0x9b2C5A51adac687867C19Bd76656702b47A24e16"
}
======
Deployment complete. Add the JSON above to `harvest-api` (https://github.com/harvest-finance/harvest-api/blob/master/data/mainnet/addresses.json) repo and add entries to `tokens.js` and `pools.js`.
```

### Regular vault (no strategy)

Deploying a regular vault with the standard reward PotPool (no pre-defined strategy, but can be added later by Governance):

```
npx hardhat run ./scripts/02-deploy-vault-regular.js --network hardhat
Regular vault deployment (no strategy).
Specify a unique ID (for the JSON) and the vault's underlying token address
prompt: id:  dai_test
prompt: underlying:  0x6B175474E89094C44Da98b954EedeAC495271d0F
======
dai_test: {
  "Underlying": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
  "NewVault": "0xd1c9CE4C3D87B2B9dDc500F6f47E65FB7d426Ac2",
  "NewStrategy": "0x0000000000000000000000000000000000000000",
  "NewPool": "0x9b2C5A51adac687867C19Bd76656702b47A24e16"
}
======
Deployment complete. Add the JSON above to `harvest-api` (https://github.com/harvest-finance/harvest-api/blob/master/data/mainnet/addresses.json) repo and add entries to `tokens.js` and `pools.js`.
```

### UniV3 Vault

Deploying a new UNI V3 vault (you must create a position token and SEND it to the specified factory (NOT MegaFactory: UniV3VaultFactory), before running the script):

```
npx hardhat run ./scripts/03-deploy-vault-univ3.js
Uniswap V3 vault deployment.
Prerequisite: create a position token using Uniswap V3, and SEND it to 0x5eaAb98ce0Ca4EE3e0dF52EDb8f0EA02fC86038c.
For this, go to https://etherscan.io/address/0xC36442b4a4522E871399CD717aBDD847Ab11FE88#writeProxyContract and do transferFrom(yourAddress, 0x5eaAb98ce0Ca4EE3e0dF52EDb8f0EA02fC86038c, <position-number>)
Specify a unique ID (for the JSON) and position token's number
prompt: id:  test_univ3
prompt: positionTokenNumber:  156967
======
test_univ3: {
  "Underlying": [
    "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
  ],
  "NewVault": "0x1AaB18Ef934bdB906b46673a59d698048742Ec32",
  "NewStrategy": "0x0000000000000000000000000000000000000000",
  "NewPool": "0xdF9db1EcdBCd590ECc5155998C14de35666EEc8f",
  "DataContract": "0x780E6B1055315a45770117a69999a8E262996e24",
  "FeeAmount": 3000,
  "PosId": [
    "26527"
  ]
}
======
Deployment complete. Add the JSON above to `harvest-api` (https://github.com/harvest-finance/harvest-api/blob/master/data/mainnet/addresses.json) repo and add entries to `tokens.js` and `pools.js`.
```
