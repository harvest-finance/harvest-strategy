# Harvest Strategy Development

This [Hardhat](https://hardhat.org/) environment is configured to use Mainnet fork by default and provides templates and utilities for strategy development and testing.

## Installation

1. Run `npm install` to install all the dependencies.
2. Sign up on [Alchemy](https://dashboard.alchemyapi.io/signup/). We recommend using Alchemy over Infura to allow for a reproducible
Mainnet fork testing environment as well as efficiency due to caching.
3. Create a file `dev-keys.json`:
  ```
    {
      "alchemyKey": "<your-alchemy-key>"
    }
  ```

## Run

All tests are located under the `test` folder.

1. In a desired test file (e.g., `./test/1inch/eth-dai.js`), look for any indication of an Ethereum block, for example:
    ```
     // external setup
     // use block 11807770
    ```
1. In `hardhat.config.js`, under `networks/hardhat/forking`, edit `blockNumber` accordingly:
    ```
    networks: {
      hardhat: {
        allowUnlimitedContractSize: true,
        forking: {
          url: "https://eth-mainnet.alchemyapi.io/v2/" + keys.alchemyKey,
          blockNumber: 11807770, // <-- edit here
        }
      }
    },
    ```
    The block number is often necessary because many tests depend on the blockchain state at a given time. For example, for using whale
    accounts that are no longer such at the most recent block, or for time-sensitive activities like migrations.
    In addition, specifying block number speeds up tests due to caching.

1. Run `npx hardhat test [test file location]`: `npx hardhat test ./test/1inch/eth-dai.js`. This will produce the following output:
    ```
    Mainnet ETH/DAI
    Impersonating...
    0xf00dD244228F51547f0563e60bCa65a30FBF5f7f
    0x9681319f4e60dD165CA2432f30D91Bb4DcFdFaa2
    Fetching Underlying at:  0x7566126f2fD0f2Dddae01Bb8A6EA49b760383D5A
    New Vault Deployed:  0x351AcA1389e546DDf78110495bc444634Ad41faE
    Strategy Deployed:  0x75565dB9a8657E21A89652F20646B03E3aDedD7b
    Strategy and vault added to Controller.
      Happy path
    loop  0
    old shareprice:  1000000000000000000
    new shareprice:  1000000000000000000
    growth:  1
    loop  1
    old shareprice:  1000000000000000000
    new shareprice:  1000487030374603469
    growth:  1.0004870303746036
    loop  2
    old shareprice:  1000487030374603469
    new shareprice:  1000974645351633413
    growth:  1.0004873776093302
    loop  3
    old shareprice:  1000974645351633413
    new shareprice:  1001462491460834661
    growth:  1.000487371095229
    loop  4
    old shareprice:  1001462491460834661
    new shareprice:  1001950555856045672
    growth:  1.000487351647588
    loop  5
    old shareprice:  1001950555856045672
    new shareprice:  1002438864026715060
    growth:  1.0004873575525413
    loop  6
    old shareprice:  1002438864026715060
    new shareprice:  1002927403398734292
    growth:  1.0004873507897099
    loop  7
    old shareprice:  1002927403398734292
    new shareprice:  1003416174066046115
    growth:  1.0004873440147866
    loop  8
    old shareprice:  1003416174066046115
    new shareprice:  1003905176131576086
    growth:  1.0004873372367005
    loop  9
    old shareprice:  1003905176131576086
    new shareprice:  1004394396967401885
    growth:  1.0004873177740858
    earned!
        ✓ Farmer should earn money (31804ms)

    1 passing (38s)
    ```

## Develop

Under `contracts/strategies`, there are plenty of examples to choose from in the repository already, therefore, creating a strategy is no longer a complicated task. Copy-pasting existing strategies with minor modifications is acceptable.

Under `contracts/base`, there are existing base interfaces and contracts that can speed up development.
Base contracts currently exist for developing SNX and MasterChef-based strategies.

We recommend favouring `StrategyBaseUL` over `StrategyBase` as the former's liquidation goes through the Universal Liquidator
that was originally developed by our community.

## Contribute

When ready, open a pull request with the following information:
1. Instructions on how to run the test and at which block number
2. A **mainnet fork test output** (like the one above in the README) clearly showing the increases of share price
3. Info about the protocol, including:
   - Live farm page(s)
   - GitHub link(s)
   - Etherscan link(s)
   - Start/end dates for rewards
   - Any limitations (e.g., maximum pool size)
   - Current Uniswap/Sushiswap/etc. pool sizes used for liquidation (to make sure they are not too shallow)

   The first few items can be omitted for well-known protocols (such as `curve.fi`).

5. A description of **potential value** for Harvest: why should your strategy be live? High APYs, decent pool sizes, longevity of rewards, well-secured protocols, high-potential collaborations, etc.

## Deployment

If your pull request is merged and given a green light for deployment, the Harvest team will take care of on-chain deployment.
