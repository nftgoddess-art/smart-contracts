usePlugin("@nomiclabs/buidler-truffle5");
usePlugin("@nomiclabs/buidler-web3");
usePlugin("@nomiclabs/buidler-etherscan");
usePlugin("@nomiclabs/buidler-ethers");
usePlugin("@openzeppelin/buidler-upgrades");
usePlugin('buidler-contract-sizer');

require("dotenv").config();

module.exports = {
  defaultNetwork: "buidlerevm",
  networks: {
    buidlerevm: {},
    ropsten: {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY],
      timeout: 20000,
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY],
      timeout: 20000,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY],
      timeout: 20000,
    },
  },
  solc: {
    version: "0.5.17",
    optimizer: {
      enabled: true,
      runs: 10000,
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
  },
  mocha: {
    enableTimeouts: false,
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
