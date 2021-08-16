require('dotenv').config();
require("@nomiclabs/hardhat-waffle");

module.exports = {
  networks: {
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: {
        mnemonic: process.env.MNEMONIC
      },
      chainId: 4
    }
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

