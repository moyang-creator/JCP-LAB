// scripts/deploy-all.js
// 一键部署三个区块链金融实验合约到 Arbitrum Orbit L3

const hre = require("hardhat");

async function main() {
  console.log("🚀 开始部署区块链金融实验合约到 Arbitrum Orbit L3...\n");

  // 1. 部署 StudentStablecoin
  const StudentStablecoin = await hre.ethers.getContractFactory("StudentStablecoin");
  const stablecoin = await StudentStablecoin.deploy();
  await stablecoin.deployed();
  console.log(`✅ StudentStablecoin (稳定币) 部署成功！`);
  console.log(`   合约地址: ${stablecoin.address}\n`);

  // 2. 部署 SimpleLendingPool（需要传入稳定币地址）
  const SimpleLendingPool = await hre.ethers.getContractFactory("SimpleLendingPool");
  const lendingPool = await SimpleLendingPool.deploy(stablecoin.address);
  await lendingPool.deployed();
  console.log(`✅ SimpleLendingPool (借贷池) 部署成功！`);
  console.log(`   合约地址: ${lendingPool.address}`);
  console.log(`   使用的稳定币地址: ${stablecoin.address}\n`);

  // 3. 部署 RWASimulation
  const RWASimulation = await hre.ethers.getContractFactory("RWASimulation");
  const rwa = await RWASimulation.deploy();
  await rwa.deployed();
  console.log(`✅ RWASimulation (RWA资产代币化) 部署成功！`);
  console.log(`   合约地址: ${rwa.address}\n`);

  console.log("🎉 所有合约部署完成！");
  console.log("📋 请保存以下合约地址：");
  console.log(`   Stablecoin: ${stablecoin.address}`);
  console.log(`   LendingPool: ${lendingPool.address}`);
  console.log(`   RWA: ${rwa.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });