# 区块链金融课程 - Arbitrum Orbit L3 实验模板

本仓库是为高校《区块链金融》课程设计的实验模板。学生可在自建的 **Arbitrum Orbit DevNet (L3)** 上部署三个升级版金融合约，理解稳定币发行、DeFi 借贷和真实世界资产 (RWA) 代币化等核心场景。

## 实验目标
- 体验派生链 (L3) 的部署与使用
- 理解智能合约如何支持真实金融场景
- 观察 Events、Gas 消耗、状态持久化、权限控制等区块链特性
- 对比 L3 与 Ethereum 主网在金融应用中的优势与权衡

## 合约列表

1. **StudentStablecoin.sol** — 升级版 ERC-20 稳定币（带 Mint/Burn 权限、暂停机制）
2. **SimpleLendingPool.sol** — 升级版借贷池（带简单利息计算、Events）
3. **RWASimulation.sol** — 升级版 RWA 资产代币化（ERC-721 + 价值绑定 + 产权转移记录）

## 使用步骤

1. 使用 Zeeve RaaS 部署自己的 Arbitrum Orbit DevNet（L3）
2. 在 Remix IDE 中连接自己的链 RPC
3. 复制 `contracts/` 中的合约到 Remix，编译并部署
4. 使用 MetaMask 与合约交互
5. 在 Block Explorer 中查看交易和 Events

## 观察重点
- Gas 费用极低（L3 优势）
- 事件日志（Events）的审计价值
- 权限控制与监管合规模拟
- 状态不可篡改性与产权登记

## 提交要求
详见课程作业说明（包含观察记录表格）。

## 技术栈
- Solidity ^0.8.20
- OpenZeppelin Contracts
- Arbitrum Orbit (L3)
- Remix IDE（推荐） / Hardhat（进阶）

Made for Blockchain Finance Course | 2026
