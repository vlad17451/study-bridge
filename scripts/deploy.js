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
  const tokenInst = await Token.deploy("Academy Token 2", "ACDM2");
  await tokenInst.deployed();
  console.log("token address:", tokenInst.address);

  await delay(10000);

  // const tokenInst = await Token.attach('')

  await tokenInst.mint(
    '0xBC6ae91F55af580B4C0E8c32D7910d00D3dbe54d',
    new BigNumber('10111').shiftedBy(18).toString()
  )

}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
