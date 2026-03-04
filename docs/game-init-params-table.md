# 游戏初始化参数表

你只需要修改 `docs/game-init-params.json`，初始化脚本会按这个文件写入链上参数。

## 1) 全局配置（`globalConfig`）

| 字段 | 含义 | 示例值 |
|---|---|---|
| `mapWidth` | 地图宽度 | `10000` |
| `mapHeight` | 地图高度 | `10000` |
| `mintIntervalBlocks` | 代币空投间隔区块数 | `100` |
| `mintAmount` | 每次空投总量（wei） | `50000000000000000000` |
| `stabilizationBlocks` | 不可靠余额稳定所需区块数 | `4000` |
| `craftDurationBlocks` | 默认锻造耗时区块数 | `3600` |
| `halvingIntervalBlocks` | 经济参数减半周期区块数 | `6048000` |
| `landPrice` | 地块价格（wei） | `100000000000000000000` |

## 2) 资源点（`resourcePoints`）

| 字段 | 含义 | 示例值 |
|---|---|---|
| `x` | 资源点坐标 x | `10` |
| `y` | 资源点坐标 y | `10` |
| `resourceType` | 资源类型 ID | `1` |
| `initialStock` | 初始库存 | `1000` |

## 3) 技能配置（`skills`）

| 字段 | 含义 | 示例值 |
|---|---|---|
| `skillId` | 技能 ID | `1` |
| `requiredBlocks` | 学习/要求区块数 | `300` |

## 4) NPC 配置（`npcs`）

| 字段 | 含义 | 示例值 |
|---|---|---|
| `npcId` | NPC ID | `1` |
| `x` | 坐标 x | `50` |
| `y` | 坐标 y | `50` |
| `skillId` | 该 NPC 可教授的技能 ID | `1` |

## 5) 配方配置（`recipes`）

先在顶层配置配方数量：

| 字段 | 含义 | 示例值 |
|---|---|---|
| `recipeCount` | `recipes` 数组条目数量 | `2` |

| 字段 | 含义 | 示例值 |
|---|---|---|
| `recipeId` | 配方 ID | `1` |
| `resourceTypes` | 消耗资源类型数组 | `[1,2]` |
| `amounts` | 对应消耗数量数组（顺序需对齐） | `[10,5]` |
| `skillId` | 需求技能 ID | `1` |
| `requiredBlocks` | 制作耗时区块数 | `300` |
| `outputEqId` | 产出装备 ID | `1001` |

## 6) 装备配置（`equipments`）

| 字段 | 含义 | 示例值 |
|---|---|---|
| `equipmentId` | 装备 ID | `1001` |
| `slot` | 装备槽位 ID | `1` |
| `speedBonus` | 速度加成（可负数） | `1` |
| `attackBonus` | 攻击加成（可负数） | `2` |
| `defenseBonus` | 防御加成（可负数） | `0` |
| `maxHpBonus` | 最大生命加成（可负数） | `10` |
| `rangeBonus` | 攻击范围加成（可负数） | `0` |

## 执行初始化

确保已设置：
- `PRIVATE_KEY`
- `RPC_URL`
- `CORE_ADDRESS`
- `CONFIG_ADDRESS`

执行：

```bash
forge script script/InitGameFromTable.s.sol:InitGameFromTableScript --rpc-url $RPC_URL --broadcast
```

如果要用其他参数文件路径，可设置：

```bash
export INIT_PARAMS_FILE=docs/game-init-params.json
```
