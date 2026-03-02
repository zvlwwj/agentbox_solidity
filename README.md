# Agentbox Solidity

Agentbox is a fully on-chain game architecture built on Ethereum. This repository contains the core smart contracts for the game, including its economy, role management, resources, and spatial mechanics. 

The project is built using the [Foundry](https://getfoundry.sh/) development framework.

## Architecture

The system follows a modular architecture built around a central, upgradeable game core.

- **`AgentboxCore`**: The main game engine (UUPS Upgradeable). Manages game state, entity positions, movements, combat, gathering, learning, and crafting.
- **`AgentboxRole` (ERC-721)**: Represents player characters (Agents) as NFTs.
- **`AgentboxRoleWallet` (ERC-6551 / TBA)**: Every role NFT gets a dedicated Tokenbound Account (Smart Contract Wallet) upon minting. This wallet holds the role's specific resources and tokens, fully isolating the game state per character.
- **`AgentboxEconomy` (ERC-20)**: The main game currency (`AGC`). Features a dual-balance system (reliable vs. unreliable money) and uses Chainlink VRF for random geographical token airdrops.
- **`AgentboxResource` (ERC-1155)**: Represents in-game resources and crafted items. Employs a custom spatial hook overriding `_update` to enforce that resource transfers between entities can only occur if they share the exact same on-chain map coordinates.
- **`AgentboxRandomizer`**: Interfaces with Chainlink VRF to handle requests for player respawn locations and NPC refreshing.
- **`AgentboxConfig`**: Centralized parameter configuration for the game (map dimensions, price variables, intervals).

## Features

- **Spatial Constraints**: Resource trading and transfers are strictly bounded by in-game coordinate logic. Two entities must be on the same tile `(x, y)` to exchange ERC-1155 resources.
- **Tokenbound Accounts**: Instead of tracking state internally via `uint256 roleId`, all entities are represented by their own `AgentboxRoleWallet` addresses, enabling native ERC-20/1155 holding and easier 3rd-party integration.
- **Customizable Land Contracts**: Players can bind their land coordinates to third-party smart contracts (e.g., custom Automated Market Makers or shops).
- **VRF Integration**: Secure, verifiable randomness for map airdrops, respawns, and NPC movements.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- (Optional) `.env` file containing your `PRIVATE_KEY`, `RPC_URL`, and `ETHERSCAN_API_KEY` for deployments.

## Setup & Installation

Clone the repository and install dependencies:

```bash
git clone https://github.com/zvlwwj/argentbox_solidity.git
cd argentbox_solidity
forge install
```

## Compilation & Testing

To compile the contracts:
```bash
forge build
```

To run the test suite:
```bash
forge test -vvv
```

## Deployment

Refer to `DEPLOY.md` for detailed instructions on deploying to testnets (e.g., Sepolia) and configuring Chainlink VRF subscriptions.

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

## License

This project is licensed under the MIT License.