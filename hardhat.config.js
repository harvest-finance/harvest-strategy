require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-ethers");
require("hardhat-gas-reporter");

const keys = require('./dev-keys.json');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      accounts: {
        mnemonic: keys.mnemonic,
      },
      allowUnlimitedContractSize: true,
      forking: {
        //url: "https://mainnet.infura.io/v3/" + keys.infuraKey,
        url: "https://eth-mainnet.alchemyapi.io/v2/" + keys.alchemyKeyMainnet,
        // blockNumber: 13984950, // <-- edit here
      },
    },
    mainnet: {
      url: "https://eth-mainnet.alchemyapi.io/v2/" + keys.alchemyKeyMainnet,
      accounts: {
        mnemonic: keys.mnemonic,
      },
    },
  },
  solidity: {
    compilers: [{
        version: "0.5.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
        },
      },
    ],
  },
  mocha: {
    timeout: 2000000,
  },
  gasReporter: {
    enabled: (process.env.REPORT_GAS) ? true : false,
    currency: 'USD',
  },
  etherscan: {
    apiKey: keys.etherscanAPI,
  },
};
