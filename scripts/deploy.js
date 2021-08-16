const hre = require("hardhat");

async function main() {
  require('dotenv').config();
  const token = await hre.ethers.getContractFactory("AcademyToken");
  const tokenInst = await token.deploy();
  await tokenInst.deployed();
  console.log("token address:", tokenInst.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
