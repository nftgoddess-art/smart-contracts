const fs = require("fs");
const { ethers } = require("@nomiclabs/buidler");
const BN = ethers.BigNumber;
const info = require("./config/rewardPoolConfig")

async function main() {
  
  // const info = JSON.parse(fs.readFileSync("script/config/rewardPoolConfig.json", "utf8"));
  const uniswapFactory = await ethers.getContractAt('IUniswapV2Factory', info.uniswapFactory);
  //========= Deploy LP token
  for (let i in info.pools.uniswap) {
    const tokenData = info.pools.uniswap[i]
    const token = tokenData.address
    console.log("------- pool ", token, info.GDS)
    let uniswapToken = await uniswapFactory.getPair(token, info.GDS);
    if(!uniswapToken || uniswapToken == "0x0000000000000000000000000000000000000000"){
      console.log("_____ create pair")
      await uniswapFactory.createPair(token, info.GDS);
      uniswapToken = await uniswapFactory.getPair(token, info.GDS);
    }
    console.log(`uniswap LP Token: ${uniswapToken}`);
  }

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
