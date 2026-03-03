# Agentbox Solidity

Agentbox is a fully on-chain game architecture built on Ethereum. This repository contains the core smart contracts for the game, including its economy, role management, resources, and spatial mechanics. 

The project is built using the [Foundry](https://getfoundry.sh/) development framework.

## 🎮 Game Mechanics & How to Play

Agentbox is a persistent, spatially-aware on-chain world where characters (Agents) navigate a grid-based map, gather resources, fight, craft, and trade. The game revolves around managing time, geographical positioning, and a unique "Unreliable" vs "Reliable" token economy.

### 1. Registration & Spawning
- **Cost**: Players must pay `0.01 ETH` to register their Agent.
- **Spawn Mechanics**: Upon registration, Chainlink VRF is called to determine a completely random and verifiable spawn coordinate `(x, y)` on the map.
- **Pioneer Bonus**: The first 2000 players to register automatically receive **Free Land Ownership** of the plot they spawn on.

### 2. Movement
Players can move their agents across the grid. Movement is bounded by the Agent's `speed` attribute.
- **Instant Movement (`move`)**: Move small distances instantly (limited by speed).
- **Asynchronous Long-Distance Travel (`startMove` / `finishMove`)**: For traveling vast distances, players initiate a move and must wait a required number of blocks based on the distance. During this time, the Agent is locked in a `Moving` state.

### 3. Economy (AGC Tokens)
The core currency is `AGC` (AgentboxCoin), which has a strict maximum supply of **160,000,000**.
- **Airdrops**: Every 100 blocks, the system randomly drops 1,000 AGC onto a random map coordinate using Chainlink VRF.
- **Unreliable Balance**: When an Agent walks over a tile with dropped tokens, they pick them up into their **"Unreliable Balance"**.
- **Stabilization**: Tokens in the Unreliable Balance cannot be freely spent yet. They must be held safely for a stabilization period (e.g., 4000 blocks). After surviving this period, they convert into "Reliable Balance" and become standard ERC-20 tokens.
- **Death Penalty**: If an Agent is killed, **ALL** of their Unreliable Balance is dropped and transferred directly to the killer!

### 4. Combat & PvP
Agents can attack other Agents within their `range` attribute.
- Damage is calculated as `Attacker's Attack - Target's Defense`.
- If an Agent's HP drops to 0, they are "killed":
  - The killer loots all of the victim's Unreliable Balance.
  - The victim is forcibly respawned at a newly randomized Chainlink VRF location.
  - Any ongoing tasks (Learning, Teaching, etc.) are immediately interrupted and cleaned up to prevent stuck states.

### 5. Gathering & Crafting
- **Gathering**: Agents can harvest resources (ERC-1155) from resource points scattered across the map. Gathering takes time (`startGather` / `finishGather`) and locks the Agent.
- **Crafting**: Agents can burn multiple gathered resources to craft Equipment (`startCrafting` / `finishCrafting`). Crafting requires specific skills and takes block time to complete.

### 6. Skills & Learning
Agents are not born with all abilities. They must learn skills to gather advanced resources or craft specific items.
- **Learning from NPCs**: Agents can find NPCs on the map and spend blocks to learn a skill from them (`startLearning`). Once learned, the NPC relocates randomly via VRF.
- **Player-to-Player Teaching**: An Agent who knows a skill can teach it to another Agent on the same tile. This requires the cooperation of both players (`startLearningFromPlayer`) and takes **twice as long** as learning from an NPC. During this time, both the student (`Learning`) and the teacher (`Teaching`) are locked in state.

### 7. Equipment System
Crafted items can be equipped to boost the Agent's base attributes (Speed, Attack, Defense, Max HP, Range).
- Equipping an item (`equip`) burns it from the character's inventory and applies the stat bonuses safely.
- Unequipping (`unequip`) reverses the stat bonuses and returns the item to the inventory.

### 8. Land Ownership & Spatial Hooks
- **Land Contracts**: Landowners can bind custom smart contracts to their coordinates (e.g., building a player-run shop or AMM on their land).
- **Spatial Inventory**: Agentbox enforces a strict spatial hook on all ERC-1155 resource transfers. You **cannot** transfer an item to another player unless your Agents are standing on the exact same `(x, y)` coordinate.

---

## 🏗 Architecture

The system follows a modular architecture built around a central, upgradeable game core.

- **`AgentboxCore`**: The main game engine (UUPS Upgradeable). Manages game state, entity positions, movements, combat, gathering, learning, equipment, and crafting.
- **`AgentboxRole` (ERC-721)**: Represents player characters (Agents) as NFTs.
- **`AgentboxRoleWallet` (ERC-6551 / TBA)**: Every role NFT gets a dedicated Tokenbound Account (Smart Contract Wallet) upon minting. This wallet holds the role's specific resources and tokens, fully isolating the game state per character.
- **`AgentboxEconomy` (ERC-20)**: The main game currency (`AGC`). Features the dual-balance system (reliable vs. unreliable money).
- **`AgentboxResource` (ERC-1155)**: Represents in-game resources and crafted items. Employs a custom spatial hook overriding `_update`.
- **`AgentboxRandomizer`**: Interfaces with Chainlink VRF to handle secure requests for player spawns, respawns, and NPC drops.
- **`AgentboxConfig`**: Centralized parameter configuration for the game (map dimensions, price variables, intervals).

## 🛠 Setup & Installation

Clone the repository and install dependencies:

```bash
git clone https://github.com/zvlwwj/argentbox_solidity.git
cd argentbox_solidity
forge install
```

## 🧪 Compilation & Testing

To compile the contracts:
```bash
forge build
```

To run the test suite:
```bash
forge test -vvv
```

## 🚀 Deployment

Refer to `DEPLOY.md` for detailed instructions on deploying to testnets (e.g., Sepolia) and configuring Chainlink VRF subscriptions.

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

## 📄 License

This project is licensed under the MIT License.