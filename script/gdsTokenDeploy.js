const fs = require("fs");
const { ethers } = require("@nomiclabs/buidler");
const BN = ethers.BigNumber;
async function main() {
  const Token = await ethers.getContractFactory("SimpleToken");
  const GoddessToken = await ethers.getContractFactory("GoddessToken");
  // const SeedPool = await ethers.getContractFactory("SeedPool");
  const goddess = await GoddessToken.deploy();
  let addresses = {};
  let pools = {};
  await goddess.deployed();
  console.log("Goddess Token deployed to:", goddess.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
