# Sushi ETH-only Vault for Harvest

Single-sided farming on SushiSwap!

## Overview

### What is this vault?

This vault allows participants to deposit ETH only and produces higher APY than received in the Sushi LP ETH/USDC vault.

- The regular ETH/USDC Sushi vault accepts deposits in Sushi ETH/USDC LP which means participants provide equal value of both USDC and ETH.

- This proposed vault does not require any USDC from participants, they can just supply the ETH side and receive the same APY (higher actually).

### What's the benefit to the community?

- ETH-only strategies are rare, and usually have poor APY.

  The current ETH strategy on Harvest farms supply on Compound which produces pretty low APY (0.27% today, not including FARM emissions). The APY in the proposed vault is even higher than Sushi LP ETH/USDC farming (56.31% at the time of writing, not including FARM emissions).

- Many participants are long on ETH and hold a lot of ETH. For them, acquiring USDC for farming has disadvantages (it lowers their ETH holdings). Normally they have to do so anyways in order to get the higher APY of Sushi LP ETH/USDC. By using this vault they can take advantage of all of their ETH without needing USDC.

### How does it work?

This strategy still does Sushi LP ETH/USDC farming under the hood so it produces the same APY. The ETH and the USDC are sourced from two different parties. ETH is sourced from Harvest participants. USDC is sourced from Orbs Liquidity Nexus (which originates from CeFi). The rewards are not divided equally. Most of the rewards go to the ETH side - giving it higher APY than ETH/USDC since it only provides half of the liquidity but receives more than half of the rewards. The party providing the USDC (external to Harvest) is still happy because the lower APY it receives is still significantly higher than returns available in CeFi.

### E2E test

The repo contains an end-to-end test (running on mainnet fork with Hardhat) that shows the entire flow. Run it from the project root.

First, in `hardhat.config.js`, under `networks/hardhat/forking` make sure `blockNumber: 12265000`

Run the test with:

```
export NODE_OPTIONS=--max_old_space_size=8192
npm install
npx hardhat test test/nexus/nexus-sushi-weth.js
```

The flow in the test is:

1. User takes ETH and deposits it in [NexusLPSushi](https://github.com/orbs-network/nexus-sushiswap) contract to mint nexus lp tokens
2. User takes the nexus lp tokens and deposits them in the proposed harvest vault
3. Initiate the vault's doHardWork
4. User withdraws from the harvest vault their nexus lp tokens
5. User takes the nexus lp tokens and removes liquidity (burn) from [NexusLPSushi](https://github.com/orbs-network/nexus-sushiswap) contract
6. User gets back more ETH than they originally put in (due to SUSHI rewards)

Test output:

```
  LiquidityNexus SushiSwap: WETH
on block number 12265000
Impersonating...
0xf1fD5233E60E7Ef797025FE9DD066d60d59BcB92
0xf00dD244228F51547f0563e60bCa65a30FBF5f7f
0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8
New Vault Deployed:  0xd88E80f91a1F5ffC0b86f65C88b70dCaa492C557
Strategy Deployed:  0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
Strategy and vault added to Controller.
farmer enters LiquidityNexus with 1000 ETH
farmer deposits NexusLP to Vault
loop  0
old shareprice:  1000000000000000000
new shareprice:  1000227950034590539
growth:  1.0002279500345905
loop  1
old shareprice:  1000000000000000000
new shareprice:  1000455807966494308
growth:  1.0004558079664942
loop  2
old shareprice:  1000000000000000000
new shareprice:  1000683712978325047
growth:  1.000683712978325
loop  3
old shareprice:  1000000000000000000
new shareprice:  1000911665077608434
growth:  1.0009116650776084
loop  4
old shareprice:  1000000000000000000
new shareprice:  1001139664272337340
growth:  1.0011396642723374
loop  5
old shareprice:  1000000000000000000
new shareprice:  1001367710570037846
growth:  1.0013677105700378
loop  6
old shareprice:  1000000000000000000
new shareprice:  1001595803978236287
growth:  1.0015958039782362
loop  7
old shareprice:  1000000000000000000
new shareprice:  1001823944504459229
growth:  1.0018239445044592
loop  8
old shareprice:  1000000000000000000
new shareprice:  1002052132156233410
growth:  1.0020521321562335
loop  9
old shareprice:  1000000000000000000
new shareprice:  1002280366941085797
growth:  1.0022803669410858
vaultBalance:  0.034947014553915009
farmer withdraws from Vault
farmer exits LiquidityNexus...
start ETH balance 10000
end ETH balance 10004.547874314234330043
principal 1000 ETH
profit 4.547874314234330043 ETH
Test duration 120 hours
profit percent 0.454787431423433 %
daily percent yield 0.0909574862846866 %
APR 33.1994824939106 %
APY 39.36404528474766 %
earned!
    ✓ Farmer should earn (40336ms)
```

## Architecture

### General concept

One party, marked _DeFi player_, deposits ETH. These are harvest users that deposit into the ETH-only harvest vault. The other party, marked _CeFi player_, deposits the USDC directly in the Nexus contract. This USDC is waiting in the contract for the ETH depositor, and once ETH is deposited, they will be paired together so they can farm together.

![diagram-harvest-readme](https://user-images.githubusercontent.com/6762255/113876704-a7d1ed80-97c0-11eb-9c40-512960f46f59.png)

The contract in blue is the proposed vault. Its source code is in this repo - [NexusLPSushiStrategy](NexusLPSushiStrategy.sol). The contract in yellow is pre-existing (not deployed by harvest) and is part of Orbs Liquidity Nexus. Its source code is available [here](https://github.com/orbs-network/nexus-sushiswap) and the deployed mainnet instance paired with this strategy is [here](https://etherscan.io/address/0x82DE6a95b5fe5CB38466686Ee09D4dC74C9b4A1a#code).

### Nexus LP tokens wrap Sushi LP tokens

In the traditional Sushi LP ETH/USDC vault, users deposit Sushi LP tokens. In our case, Nexus LP tokens replace the Sushi LP tokens. Implementation wise, Nexus LP is a very thin wrapper around Sushi LP. This wrapper provides the pairing with USDC that is waiting in the Nexus LP contract. The contract implementing the Nexus LP wrapper is [NexusLPSushi](https://github.com/orbs-network/nexus-sushiswap).

### Detailed step by step flow

This flow assumes that there is already a large amount of USDC waiting in [NexusLPSushi](https://github.com/orbs-network/nexus-sushiswap). This USDC is deployed in advance.

1. User takes ETH and deposits it in [NexusLPSushi](https://github.com/orbs-network/nexus-sushiswap) contract to mint nexus lp tokens:

   - User sends ETH to `NexusLPSushi.addLiquidityETH` and receives in return `NexusLPSushi` ERC20 tokens.

2. User takes the nexus lp tokens and deposits them in the proposed harvest vault:

   - User calls `NexusLPSushi.approve` with the vault address.
   - User calls `Vault.deposit` to transfer the `NexusLPSushi` tokens to the vault.

3. Initiate the vault's doHardWork:

   - `NexusLPSushi` tokens move from the vault to the `NexusLPSushiStrategy` strategy.
   - The strategy calls `NexusLPSushi.claimRewards` to receive all pending SUSHI rewards.
   - The strategy liquidates SUSHI rewards to ETH after taking profit sharing fee.
   - The strategy compounds the ETH by calling `NexusLPSushi.compoundProfits` to increase the value of `NexusLPSushi`.

4. User withdraws from the harvest vault their nexus lp tokens:

   - User calls `Vault.withdraw` to receive their `NexusLPSushi` tokens back.

5. User takes the nexus lp tokens and removes liquidity (burn) from [NexusLPSushi](https://github.com/orbs-network/nexus-sushiswap) contract:

   - User calls `NexusLPSushi.removeLiquidityETH` which burns their `NexusLPSushi` tokens in return for ETH.

6. User gets back more ETH than they originally put in (due to SUSHI rewards)

## Further reading

### What is Orbs Liquidity Nexus?

[Orbs Liquidity Nexus](https://nexus.orbs.com) is a project by [Orbs](https://orbs.com) blockchain team that introduces CeFi sourced liquidity to popular DeFi projects like harvest. Here are some Medium posts that explain in more detail:

- [Introducing Orbs Liquidity Nexus - Liquidity as a Service](https://medium.com/@talkol/introducing-orbs-liquidity-nexus-liquidity-as-a-service-1c022c8f2d43)
- [Single Sided-Farming on Any DEX Via Orbs Liquidity Nexus - Part 1](https://medium.com/@talkol/single-sided-farming-on-any-dex-via-orbs-liquidity-nexus-part-1-520051f940d5)
- [Single Sided-Farming on Any DEX Via Orbs Liquidity Nexus - Part 2](https://medium.com/@talkol/single-sided-farming-on-any-dex-via-orbs-liquidity-nexus-part-2-824e58057cb5)
- [Single Sided-Farming on Any DEX Via Orbs Liquidity Nexus - Part 3](https://medium.com/@talkol/single-sided-farming-on-any-dex-via-orbs-liquidity-nexus-part-3-fb75efb2f91f)
