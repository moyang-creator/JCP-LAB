require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    // 学生需要在这里配置自己的 Orbit DevNet
    orbitDevnet: {
      url: process.env.ORBIT_RPC_URL || "https://your-orbit-rpc-url-here", 
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: parseInt(process.env.CHAIN_ID || "421614") // 默认 Arbitrum Sepolia
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};