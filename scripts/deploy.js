// scripts/deploy.js
// 用法示例：
// npx hardhat run scripts/deploy.js --network orbitDevnet --contract stablecoin

const hre = require("hardhat");

async function main() {
  const contractName = process.env.CONTRACT || "stablecoin";

  console.log(`🚀 正在部署 ${contractName} ...\n`);

  let contract, address;

  switch (contractName.toLowerCase()) {
    case "stablecoin":
      const StudentStablecoin = await hre.ethers.getContractFactory("StudentStablecoin");
      contract = await StudentStablecoin.deploy();
      address = contract.address;
      console.log(`✅ StudentStablecoin 部署成功！地址: ${address}`);
      break;

    case "lendingpool":
      // 这里需要先手动输入稳定币地址（可后续改进）
      const stablecoinAddress = "请输入你的稳定币合约地址"; 
      const SimpleLendingPool = await hre.ethers.getContractFactory("SimpleLendingPool");
      contract = await SimpleLendingPool.deploy(stablecoinAddress);
      address = contract.address;
      console.log(`✅ SimpleLendingPool 部署成功！地址: ${address}`);
      break;

    case "rwa":
      const RWASimulation = await hre.ethers.getContractFactory("RWASimulation");
      contract = await RWASimulation.deploy();
      address = contract.address;
      console.log(`✅ RWASimulation 部署成功！地址: ${address}`);
      break;

    default:
      console.log("❌ 请指定合约：stablecoin / lendingpool / rwa");
      process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });