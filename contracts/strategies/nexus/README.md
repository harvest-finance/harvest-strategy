# Sushi ETH-only Vault for Harvest

Single-sided farming on SushiSwap!

## Overview

### What is this vault?

This vault allows participants to deposit ETH only and produces higher APY than received in the Sushi ETH/USDC vault.

* The regular ETH/USDC Sushi vault accepts deposits in Sushi ETH/USDC LP which means participants provide equal value of both USDC and ETH.

* This proposed vault does not require any USDC from participants, they can just supply the ETH side and receive the same APY (higher actually).

### What's the benefit to the community?

* ETH-only strategies are rare, and usually have poor APY.

    The current ETH strategy on Harvest farms supply on Compound which produces pretty low APY (0.27% today not including FARM emissions). The APY in the proposed vault is even higher than Sushi ETH/USDC farming (28.29% today not including FARM emissions).

* Many participants are long on ETH and hold a lot of ETH. For them, acquiring USDC for farming has disadvantages (it lowers their ETH holdings). Normally they have to do so anyways in order to get the higher APY of Sushi ETH/USDC. By using this vault they can take advantage of all of their ETH without needing USDC.

### How does it work?

This strategy still does Sushi ETH/USDC farming under the hood so it produces the same APY. The ETH and the USDC are sourced from two different parties. ETH is sourced from Harvest participants. USDC is sourced from Orbs Liquidity Nexus (which originates from CeFi). The rewards are not divided equally. Most of the rewards go to the ETH side - giving it higher APY than ETH/USDC since it only provides half of the liquidity but receives more than half of the rewards. The party providing the USDC (external to Harvest) is still happy because the lower APY it receives is still significantly higher than returns available in CeFi.

### E2E test

The repo contains an end-to-end test (running on mainnet fork with Hardhat) that shows the entire flow. Run it with:

```
export NODE_OPTIONS=--max_old_space_size=8192
npm install
npx hardhat test test/nexus/nexus-sushi-weth.js
```

The flow in the test is:

1. User takes ETH and deposits it in [NexusLP_SushiUSDC](https://github.com/orbs-network/nexus-sushiswap) contract to mint nexus lp tokens
2. User takes the nexus lp tokens and deposits them in the proposed harvest vault
3. Initiate the vault's doHardWork
4. User withdraws from the harvest vault their nexus lp tokens
5. User takes the nexus lp tokens and removes liquidity (burn) from [NexusLP_SushiUSDC](https://github.com/orbs-network/nexus-sushiswap) contract
6. User gets back more ETH than they originally put in (due to SUSHI rewards)

## Architecture

### General concept

One party, marked *DeFi player*, deposits ETH. These are harvest users that deposit into the ETH-only harvest vault. The other party, marked *CeFi player*, deposits the USDC directly in the Nexus contract. This USDC is waiting in the contract for the ETH depositor, and once ETH is deposited, they will be paired together so they can farm together.

![diagram-harvest-readme1](https://user-images.githubusercontent.com/6762255/113769400-a2759400-9729-11eb-884a-7b1d5689d6a5.png)

The contract in blue is the proposed vault. Its source code is in this repo - [NexusSushiStrategyMainnet_WETH](NexusSushiStrategyMainnet_WETH.sol). The contract in yellow is pre-existing (not deployed by harvest) and is part of Orbs Liquidity Nexus. Its source code is available [here](https://github.com/orbs-network/nexus-sushiswap).

### Nexus LP tokens wrap Sushi LP tokens

In the traditional Sushi ETH/USDC vault, users deposit Sushi LP tokens. In our case, Nexus LP tokens replace the Sushi LP tokens. Implementation wise, Nexus LP is a very thin wrapper around Sushi LP. This wrapper provides the pairing with USDC that is waiting in the Nexus LP contract. The contract implementing the Nexus LP wrapper is [NexusLP_SushiUSDC](https://github.com/orbs-network/nexus-sushiswap).

### Detailed step by step flow

This flow assumes that there is already a large amount of USDC waiting in [NexusLP_SushiUSDC](https://github.com/orbs-network/nexus-sushiswap). This USDC is deployed in advance.

1. User takes ETH and deposits it in [NexusLP_SushiUSDC](https://github.com/orbs-network/nexus-sushiswap) contract to mint nexus lp tokens:

    * User sends ETH to `NexusLP_SushiUSDC.addLiquidityETH` and receives in return `NexusLP_SushiUSDC` ERC20 tokens.
    
2. User takes the nexus lp tokens and deposits them in the proposed harvest vault:

    * User calls `NexusLP_SushiUSDC.approve` with the vault address.
    * User calls `Vault.deposit` to transfer the `NexusLP_SushiUSDC` tokens to the vault.

4. Initiate the vault's doHardWork:

    * `NexusLP_SushiUSDC` tokens move from the vault to the `NexusSushiStrategyMainnet_WETH` strategy.
    * The strategy calls `NexusLP_SushiUSDC.claimRewards` to receive all pending SUSHI rewards.
    * The strategy liquidates SUSHI rewards to ETH after taking profit sharing fee.
    * The strategy compounds the ETH by calling `NexusLP_SushiUSDC.compoundProfits` to increase the value of `NexusLP_SushiUSDC`.

5. User withdraws from the harvest vault their nexus lp tokens:

    * User calls `Vault.withdraw` to receive their `NexusLP_SushiUSDC` tokens back.

6. User takes the nexus lp tokens and removes liquidity (burn) from [NexusLP_SushiUSDC](https://github.com/orbs-network/nexus-sushiswap) contract:

    * User calls `NexusLP_SushiUSDC.removeLiquidityETH` which burns their `NexusLP_SushiUSDC` tokens in return for ETH.

7. User gets back more ETH than they originally put in (due to SUSHI rewards)

## Further reading

### What is Orbs Liquidity Nexus?

[Orbs Liquidity Nexus](https://nexus.orbs.com) is a project by [Orbs](https://orbs.com) blockchain team that introduces CeFi sourced liquidity to popular DeFi projects like harvest. Here are some Medium posts that explain in more detail:

* [Introducing Orbs Liquidity Nexus - Liquidity as a Service](https://medium.com/@talkol/introducing-orbs-liquidity-nexus-liquidity-as-a-service-1c022c8f2d43)
* [Single Sided-Farming on Any DEX Via Orbs Liquidity Nexus - Part 1](https://medium.com/@talkol/single-sided-farming-on-any-dex-via-orbs-liquidity-nexus-part-1-520051f940d5)
* [Single Sided-Farming on Any DEX Via Orbs Liquidity Nexus - Part 2](https://medium.com/@talkol/single-sided-farming-on-any-dex-via-orbs-liquidity-nexus-part-2-824e58057cb5)
* [Single Sided-Farming on Any DEX Via Orbs Liquidity Nexus - Part 3](https://medium.com/@talkol/single-sided-farming-on-any-dex-via-orbs-liquidity-nexus-part-3-fb75efb2f91f)
