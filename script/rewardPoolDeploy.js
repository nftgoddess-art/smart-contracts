const fs = require("fs");
const { ethers } = require("@nomiclabs/buidler");
const BN = ethers.BigNumber;
const info = require("./config/rewardPoolConfig")
async function main() {
  
  // let info = JSON.parse(fs.readFileSync("script/config/rewardPoolConfig.json", "utf8"));
  //====== deploy Goddess.sol
  const Goddess = await ethers.getContractFactory("Goddess");
  const goddessNft = await Goddess.deploy(
    info.goddessName,
    info.goddessSymbol,
    info.proxyRegistryAddress
  );
  await goddessNft.deployed();
  console.log("Goddess deployed to:", goddessNft.address);

  const GoddessFragments = await ethers.getContractFactory("GoddessFragments");
  const fragments = await GoddessFragments.deploy(
    info.fragmentsAdmin,
    info.GDS,
    goddessNft.address,
    info.uniswapRouter
  );
  await fragments.deployed();
  console.log("Goddess Fragments deployed to:", fragments.address);

  await goddessNft.addOperator(fragments.address)
  console.log("-- setted fragment as Goddess NFT operator")

  //************** Deploy reward pool ****************//

  let pools = {};
  const RewardPool = await ethers.getContractFactory("FragmentsPool");
  // const uniswapFactory = await ethers.getContractAt('IUniswapV2Factory', info.uniswapFactory);
  const goddess = await ethers.getContractAt("GoddessToken", info.GDS);
  //====== deploy single GDS pool
  const singleGDSpool = await RewardPool.deploy(
    new BN.from(2).pow(256).sub(1), //max cap
    info.GDS,  // stake token address
    info.GDS, // goddess token
    info.uniswapRouter,
    info.startTime,
    info.duration,
    fragments.address
  );
  console.log(`Pool single GDS deployed to: ${singleGDSpool.address}`)
  let singleGDSpoolReward = new BN.from(info.pools.singleGDS.rewardAmount).mul(
    new BN.from(10).pow(new BN.from(18))
  );
  await goddess.transfer(singleGDSpool.address, singleGDSpoolReward);
  console.log(`Transfered reward ${info.pools.singleGDS.rewardAmount} GDS`)
  await singleGDSpool.setGovernance(info.treasuary);
  console.log("________ setted Governance")
  await singleGDSpool.setReferral(info.referral)
  console.log("________ setted referral")
  await singleGDSpool.setFragmentsPerWeek(
    new BN.from(info.pools.singleGDS.fragmentPerWeek).mul(
      new BN.from(10).pow(new BN.from(18))
    )
  )
  console.log("________ setted FragmentsPerWeek")
  await singleGDSpool.notifyRewardAmount(singleGDSpoolReward);
  console.log("________ setted notifyRewardAmount")
  await fragments.addOperator(singleGDSpool.address)
  console.log("________ setted operator")
  pools.GDS = singleGDSpool.address

  
  //========= Deploy pair pool: uniswap and balancer
  const pairPool = [...info.pools.uniswap, ...info.pools.balancer]
  for (let i in pairPool) {
    const tokenData = pairPool[i]
    const pool = await RewardPool.deploy(
      new BN.from(2).pow(256).sub(1), //token cap
      tokenData.pairToken,  // stake token address
      info.GDS, // goddess token
      info.uniswapRouter,
      info.startTime,
      info.duration,
      fragments.address
    );
    console.log(`Pool ${tokenData.token}-GDS deployed to: ${pool.address}`)

    let reward = new BN.from(tokenData.rewardAmount).mul(
      new BN.from(10).pow(new BN.from(18))
    );
    await goddess.transfer(pool.address, reward);
    console.log(`Transfered reward ${tokenData.rewardAmount} GDS`)
    await pool.setGovernance(info.treasuary);
    console.log("________ setted Governance")
    await pool.setReferral(info.referral)
    console.log("________ setted referral")
    await pool.setFragmentsPerWeek(
      new BN.from(tokenData.fragmentPerWeek).mul(
        new BN.from(10).pow(new BN.from(18))
      )
    )
    console.log("________ setted FragmentsPerWeek")
    await pool.notifyRewardAmount(reward);
    console.log("________ setted notifyRewardAmount")
    await fragments.addOperator(pool.address)
    console.log("________ setted operator")
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
