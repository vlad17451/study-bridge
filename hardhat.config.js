require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require('hardhat-docgen');

const accounts = process.env.MNEMONIC
  ? { mnemonic: process.env.MNEMONIC }
  : undefined;

module.exports = {
  docgen: {
    path: './doc',
    clear: true,
    // runOnCompile: true,
  },
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts,
      chainId: 11155111
    },
    bscTestnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      chainId: 97,
      accounts,
    }
  },
  solidity: {
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
