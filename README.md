# 区块链金融课程 - Arbitrum Orbit 实验实验室

**课程名称**：《区块链金融》  
**实验主题**：自建 Arbitrum Orbit 链（L2 / L3）并部署金融智能合约  
**实验目标**：通过实际动手操作，理解派生链（L2/L3）、稳定币发行、DeFi 借贷池以及真实世界资产（RWA）代币化等区块链金融核心概念，并对比 L2 与 L3 的差异。

---

## 一、实验概述

本次实验中，你将：
- 使用 Zeeve RaaS 部署一条属于自己的 **Arbitrum Orbit 链**（可选择 L2 或 L3）
- 在自己的链上部署三个升级版金融智能合约
- 通过 MetaMask 和 Remix IDE 与合约交互，观察区块链金融实际运行现象
- 对比 L2 和 L3 在金融应用中的性能与权衡

---

## 二、L2 与 L3 部署选项说明（重要）

本次实验提供 **两种部署模式**：

| 项目                  | **L3（推荐）**                                      | **L2**                                              |
|-----------------------|----------------------------------------------------|----------------------------------------------------|
| **Settlement Layer** | Arbitrum Sepolia（L2）                             | Ethereum Sepolia（L1）                             |
| **层级**             | **Layer 3**（构建在 L2 之上）                      | **Layer 2**（直接构建在 Ethereum 之上）            |
| **Gas 费用**         | 通常更低，体验更好                                 | 相对较高                                           |
| **安全性**           | 继承 Arbitrum L2 + Ethereum L1                     | 直接继承 Ethereum L1                               |
| **适用场景**         | 适合高频交易、游戏、专用金融应用（如 RWA）         | 适合需要最高安全性的通用金融应用                   |
| **推荐人群**         | 大多数学生（推荐）                                 | 有余力或想深入对比的学生                           |

**建议**：优先选择 **L3** 进行实验，Gas 费用更低，操作体验更好。优秀学生可同时部署 L2 和 L3 两条链，并在报告中进行对比分析。

---

## 三、实验所需工具

- MetaMask 钱包
- Remix IDE（推荐）：https://remix.ethereum.org/
- Zeeve 账号（免费）：https://app.zeeve.io/
- Docker Desktop（可选，用于运行本地节点）
- Node.js + Hardhat（可选进阶部署）

---

## 四、详细实验步骤

### 步骤 1：部署自己的 Arbitrum Orbit 链（L2 或 L3）

1. 登录 [Zeeve](https://app.zeeve.io/) 并进入 **Appchains & Rollups → Arbitrum Orbit**。
2. 点击 **Deploy DevNet**.
3. 配置以下参数（可自定义）：

   - **Network Name**：例如 `JCP-你的学号-FinanceL3`（推荐带学号）
   - **Settlement Layer**（关键选择）：
     - **L3（推荐）**：选择 **Arbitrum Sepolia（L2）**
     - **L2（可选）**：选择 **Ethereum Sepolia（L1）**
   - **Data Availability**：推荐选择 **AnyTrust**
   - **Gas Token**：ETH（默认）

4. 点击 **Deploy**，等待 3–8 分钟。
5. 保存以下信息（强烈建议截图）：
   - RPC URL
   - Chain ID
   - Block Explorer URL

### 步骤 2：将自己的链添加到 MetaMask

1. 打开 MetaMask → 点击顶部网络 → **添加网络** → **添加自定义网络**
2. 填写 Zeeve 提供的参数并保存
3. 切换到你刚刚部署的链

### 步骤 3：在 Remix IDE 中部署合约（推荐方式）

1. 打开 [Remix IDE](https://remix.ethereum.org/)
2. 创建以下三个文件并粘贴对应代码（代码见下方 `contracts/` 目录）：
   - `StudentStablecoin.sol`
   - `SimpleLendingPool.sol`
   - `RWASimulation.sol`
3. 编译合约（Solidity 版本 0.8.20）
4. 在 **Deploy & Run Transactions** 中选择 **Injected Provider - MetaMask**
5. 依次部署三个合约（推荐顺序：稳定币 → 借贷池 → RWA）

**注意**：部署 `SimpleLendingPool` 时，构造函数需要传入 `StudentStablecoin` 的合约地址。

### 步骤 4（可选进阶）：使用 Hardhat 脚本部署

```bash
# 1. 克隆仓库并安装依赖
git clone <你的仓库地址>
cd JCP-LAB
npm install

# 2. 创建 .env 文件并填写以下内容
ORBIT_RPC_URL=你的Orbit RPC URL
PRIVATE_KEY=你的测试网私钥（小心保管）

# 3. 一键部署所有合约（推荐）
npx hardhat run scripts/deploy-all.js --network orbitDevnet

# 或单独部署某个合约
npx hardhat run scripts/deploy.js --network orbitDevnet