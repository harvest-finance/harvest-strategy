require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-truffle5");
require("hardhat-gas-reporter");

const keys = require('./dev-keys.json');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      forking: {
        //url: "https://mainnet.infura.io/v3/" + keys.infuraKey,
        url: "https://eth-mainnet.alchemyapi.io/v2/" + keys.alchemyKey,
        blockNumber: 11807770, // <-- edit here
      }
    }
  },
  solidity: {
    compilers: [
      {version: "0.5.16"},
    ]
  },
  mocha: {
    timeout: 2000000
  },
  gasReporter: {
    enabled: (process.env.REPORT_GAS) ? true : false,
    currency: 'USD'
  }
};
