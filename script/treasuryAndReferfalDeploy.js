const fs = require("fs");
const { ethers } = require("@nomiclabs/buidler");
const BN = ethers.BigNumber;
const info = require("./config/treasuryAndReferfal")
async function main() {
  
  // let info = JSON.parse(fs.readFileSync("script/config/treasuryAndReferfal.json", "utf8"));

  // deploy Goddess.sol
  const vestingAmount = new BN.from(info.totalLock).mul(new BN.from(10).pow(new BN.from(18)))
  const endTime = info.startTime + info.monthLock * 60 * 60 * 24 * 30;
  const Treasury = await ethers.getContractFactory("GoddessTreasury");
  console.log("---------------------", info.USDT,
  info.GDS,
  vestingAmount.toString(),
  info.startTime,
  endTime,
  info.admin)
  const treasuryDeployment = await Treasury.deploy(
    info.USDT,
    info.GDS,
    vestingAmount,
    info.startTime,
    endTime,
    info.admin
  );
  await treasuryDeployment.deployed();
  console.log("Treasury deployed to:", treasuryDeployment.address);
  let goddess = await ethers.getContractAt("GoddessToken", info.GDS);
  const totalHoldAmount = new BN.from(info.totalHold).mul(new BN.from(10).pow(new BN.from(18)))
  await goddess.transfer(treasuryDeployment.address, totalHoldAmount);
  console.log(`Transfered ${info.totalHold} GDS to treasuary`)

  const Referral = await ethers.getContractFactory("Referral");
  const referralDeployment = await Referral.deploy(
    info.admin
  );
  await referralDeployment.deployed();
  console.log("Referral deployed to:", referralDeployment.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
