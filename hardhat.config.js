require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

module.exports = {
  networks: {
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: {
        mnemonic: process.env.MNEMONIC
      },
      chainId: 4
    },
    bscTestnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      chainId: 97,
      accounts: {
        mnemonic: process.env.MNEMONIC
      },
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    // apiKey: "FJN5Z6K1NU9URU3ANDC3QUDKDE7ZPKTIAB", // eth
    apiKey: "N4R6CJ9JM1U2PGJ7MWDUXYYJFUYJYNACH8" // bsc
  },
  solidity: {
    docker: false,
    parser: 'solcjs',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    },
    compilers: [
      {
        version: "0.8.4"
      },
    ]
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 20000
  }
}

