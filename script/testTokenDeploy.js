const fs = require("fs");
const { ethers } = require("@nomiclabs/buidler");
const BN = ethers.BigNumber;
const testTokensInfo = require("./config/testToken")
async function main() {
  const Token = await ethers.getContractFactory("SimpleToken");
  let addresses = {};

  // let testTokensInfo = JSON.parse(
  //   fs.readFileSync("script/config/testToken.json", "utf8")
  // );
  for (let tokenInfo of testTokensInfo.tokens) {
    let token = await Token.deploy(
      tokenInfo.name,
      tokenInfo.symbol,
      tokenInfo.decimals
    );
    await token.deployed();
    console.log(`${ tokenInfo.symbol} deployed to: ${token.address}`);
    for (let admin of testTokensInfo.admins) {
      await token.transfer(
        admin.address,
        (new BN.from(50000)).mul((new BN.from(10)).pow(new BN.from(tokenInfo.decimals)))
      )
      console.log(`successfully transfer 50000 ${tokenInfo.symbol} to ${admin.name} address`)
    }
    addresses[tokenInfo.symbol] = token.address;
  }
  console.log(addresses);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
