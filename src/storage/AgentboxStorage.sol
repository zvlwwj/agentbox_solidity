// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library AgentboxStorage {
    enum RoleState {
        Idle,
        Learning,
        Teaching,
        Crafting,
        Gathering
    }

    struct Position {
        uint256 x;
        uint256 y;
    }

    struct RoleAttributes {
        uint256 speed;
        uint256 attack;
        uint256 defense;
        uint256 hp;
        uint256 maxHp;
        uint256 range;
        uint256 mp;
    }

    struct CraftingState {
        uint256 startBlock;
        uint256 requiredBlocks;
        uint256 recipeId;
    }

    struct LearningState {
        uint256 startBlock;
        uint256 requiredBlocks;
        uint256 targetId;
        uint256 skillId;
    }

    struct RoleData {
        Position position;
        RoleAttributes attributes;
        RoleState state;
        CraftingState crafting;
        LearningState learning;
        mapping(uint256 => bool) skills;
    }

    struct ResourcePoint {
        uint256 resourceType;
        uint256 stock;
        bool isResourcePoint;
    }

    struct NPC {
        uint256 npcType;
        Position position;
        bool isTeaching;
        uint256 studentId;
        uint256 startBlock;
        uint256 requiredBlocks;
    }

    struct Recipe {
        uint256 requiredResource;
        uint256 requiredAmount;
        uint256 requiredSkill;
        uint256 requiredBlocks;
        uint256 outputEquipmentId;
    }

    struct GameState {
        address roleContract;
        address configContract;
        address economyContract;
        address randomizerContract;
        address resourceContract;
        mapping(address => RoleData) roles;
        mapping(uint256 => address) landOwners;
        mapping(uint256 => address) landContracts; // landId => custom smart contract address
        mapping(address => uint256) contractToLand; // custom smart contract address => landId
        mapping(address => bool) isLandContract; // verify if address is a registered land contract
        mapping(uint256 => ResourcePoint) resourcePoints;
        mapping(uint256 => NPC) npcs;
        mapping(uint256 => Recipe) recipes;
        uint256[39] __gap;
    }

    bytes32 constant GAME_STORAGE_POSITION = keccak256("agentbox.core.storage");

    function getStorage() internal pure returns (GameState storage gs) {
        bytes32 position = GAME_STORAGE_POSITION;
        assembly {
            gs.slot := position
        }
    }
}
