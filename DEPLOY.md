# Agentbox 部署与验证指南

## 环境准备
确保已安装 Foundry 工具链:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## 测试与编译
运行全套单元测试，并开启优化编译：
```bash
forge test -vvv
forge build
```

## 测试网部署 (以 Sepolia 为例)
1. 配置你的私钥和 RPC URL (可以在 `.env` 文件中设置):
```bash
export PRIVATE_KEY=你的钱包私钥
export RPC_URL=https://rpc.sepolia.org
export ETHERSCAN_API_KEY=你的EtherscanAPIKey
```

2. 运行部署脚本:
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

3. 部署后，你将获得各个合约的地址。需要前往 Chainlink VRF 官网为 `AgentboxRandomizer` 和 `AgentboxEconomy` 合约配置对应的 Subscription 并充值 LINK 测试币。

## 合约架构说明
- `AgentboxRole`: ERC721 角色凭证与租赁系统
- `AgentboxConfig`: 游戏内的各项全局配置与魔法参数
- `AgentboxEconomy`: 基于 ERC20 的代币逻辑及金钱稳定化处理 (接入 VRF 进行地图空投)
- `AgentboxRandomizer`: 专用的 Chainlink VRF 代理合约，负责复活与 NPC 刷新随机数回调
- `AgentboxCore`: UUPS 可升级主逻辑合约，包含状态机、战斗、地图移动及资源装备核心链路。
