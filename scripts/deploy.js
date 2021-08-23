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
  const tokenInst = await Token.deploy("Academy Token", "ACDM");
  await tokenInst.deployed();
  console.log("token address:", tokenInst.address);

  // npx hardhat verify --network rinkeby "0xf6F42851d674AC70241822F201aF46299329D5F7" "Academy Token" "ACDM"

  // await delay(5000);
  //
  // // const tokenInst = await Token.attach('0x174A683F9caCDB6Da6B9a6a637204971437bB5FA')
  //
  // await tokenInst.mint(
  //   '0xBC6ae91F55af580B4C0E8c32D7910d00D3dbe54d',
  //   new BigNumber('10000').shiftedBy(18).toString()
  // )

}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
