const hre = require("hardhat");
const BigNumber = require("bignumber.js")
BigNumber.config({ EXPONENTIAL_AT: 60 });

const delay = async (time) => {
  return new Promise((resolve) => {
    setInterval(() => {
      resolve()
    }, time)
  })
}

async function main() {
  require('dotenv').config();
  const Token = await hre.ethers.getContractFactory("AcademyToken");
  const Bridge = await hre.ethers.getContractFactory("Bridge");
  const bridge = await Bridge.deploy('97');
  await bridge.deployed();
  console.log("bridge address:", bridge.address);

  await delay(1000);

  const VALIDATOR_ROLE = await bridge.VALIDATOR_ROLE()
  await bridge.grantRole(VALIDATOR_ROLE, '0xBC6ae91F55af580B4C0E8c32D7910d00D3dbe54d')

  // const bridge = await Bridge.attach('')

  await bridge.updateChainById('4', true)

  const tokenAddresses = [
    '0x9995E70932A746B0e37c3b2892124B4F868655Ca', // ACDM
    '0x4CFB87755629847c4739b77364c2f1DB1D4397A0' // ACDM2
  ]

  const tokens = await Promise.all(tokenAddresses.map(address => {
    return Token.attach(address)
  }))

  await delay(1000);


  const MINTER_ROLE = await tokens[0].MINTER_ROLE()
  const BURNER_ROLE = await tokens[0].BURNER_ROLE()

  await delay(1000);

  for (let i = 0; i < tokens.length; i += 1) {
    const token = tokens[i]

    await token.grantRole(MINTER_ROLE, bridge.address)
    await token.grantRole(BURNER_ROLE, bridge.address)
    const symbol = await token.symbol()
    await bridge.addToken(symbol, token.address)
    await delay(2000);
  }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
