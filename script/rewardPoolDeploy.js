const fs = require("fs");
const { ethers } = require("@nomiclabs/buidler");
const BN = ethers.BigNumber;

async function main() {
  
  let info = JSON.parse(fs.readFileSync("script/config/rewardPoolConfig.json", "utf8"));

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
  const uniswapFactory = await ethers.getContractAt('IUniswapV2Factory', info.uniswapFactory);
  const goddess = await ethers.getContractAt("GoddessToken", info.GDS);
  //====== deploy single GDS pool
  const singleGDSpool = await RewardPool.deploy(
    new BN.from(info.pools.singleGDS.maxCap).mul(new BN.from(10).pow(18)), //token cap
    info.GDS,  // stake token address
    goddessNft.address, // goddess token
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
  await singleGDSpool.setReferral(info.referral)
  await singleGDSpool.setFragmentsPerWeek(
    new BN.from(info.pools.singleGDS.fragmentPerWeek).mul(
      new BN.from(10).pow(new BN.from(18))
    )
  )
  await singleGDSpool.notifyRewardAmount(singleGDSpoolReward);
  await fragments.addOperator(singleGDSpool.address)
  pools.GDS = singleGDSpool.address

  
  //========= Deploy LP pool
  for (let i in info.pools.uniswap) {
    const tokenData = info.pools.uniswap[i]
    const token = tokenData.address
    console.log("------- pool ", token, info.GDS)
    let uniswapToken = await uniswapFactory.getPair(token, info.GDS);
    if(!uniswapToken || uniswapToken == "0x0000000000000000000000000000000000000000"){
      console.log("_____ create pair")
      await uniswapFactory.createPair(token, info.GDS);
      uniswapToken = await uniswapFactory.getPair(token, info.GDS);
      if(uniswapToken == "0x0000000000000000000000000000000000000000"){
        console.log("cannot create LP token");
        return
      }
    }
    console.log(`uniswap LP Token: ${uniswapToken}`);

    const pool = await RewardPool.deploy(
      new BN.from(tokenData.maxCap).mul(new BN.from(10).pow(18)), //token cap
      uniswapToken,  // stake token address
      goddessNft.address, // goddess token
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
    await pool.setReferral(info.referral)
    await pool.setFragmentsPerWeek(
      new BN.from(tokenData.fragmentPerWeek).mul(
        new BN.from(10).pow(new BN.from(18))
      )
    )
    await pool.notifyRewardAmount(reward);
    await fragments.addOperator(pool.address)

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
