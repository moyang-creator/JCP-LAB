require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.20",
  networks: {
    // 学生可在此添加自己的 Orbit DevNet RPC
    orbitDevnet: {
      url: "YOUR_ORBIT_RPC_URL_HERE",
      accounts: ["YOUR_PRIVATE_KEY"] // 仅测试使用
    }
  }
};
