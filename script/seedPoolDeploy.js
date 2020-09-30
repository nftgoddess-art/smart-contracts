const fs = require("fs");
const { ethers } = require("@nomiclabs/buidler");
const BN = ethers.BigNumber;

async function main() {
  const SeedPool = await ethers.getContractFactory("SeedPool");
  let info = JSON.parse(fs.readFileSync("script/config/seedPoolConfig.json", "utf8"));
  let gdsAddress = info.GDS;
  let goddess = await ethers.getContractAt("GoddessToken", gdsAddress);
  let pools = {};
  for (let i in info.pool) {
    let tokenData = info.pool[i];
    let address = tokenData.address;
    // let maxCap = new BN.from(tokenData.maxCap);
    let pool = await SeedPool.deploy(
      new BN.from(tokenData.maxCap).mul(new BN.from(10).pow(new BN.from(tokenData.decimals))),
      address,
      gdsAddress,
      info.startTime,
      info.duration
    );
    console.log(`Pool ${tokenData.token} deployed to: ${pool.address}`)
    let rewardAmount = new BN.from(tokenData.rewardAmount).mul(
      new BN.from(10).pow(new BN.from(18))
    );
    await goddess.transfer(pool.address, rewardAmount);
    console.log(`Transfered reward ${tokenData.rewardAmount} GDS`)
    await pool.notifyRewardAmount(rewardAmount);
    await pool.setReferral(info.referral)
    pools[tokenData.token] = pool.address;
  }
  console.log(pools);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
