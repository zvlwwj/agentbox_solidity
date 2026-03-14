// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library AgentboxStorage {
    enum RoleState {
        Idle,
        Learning,
        Teaching,
        Crafting,
        Gathering,
        Teleporting,
        PendingSpawn
    }

    struct Position {
        uint32 x;
        uint32 y;
    }

    struct RoleAttributes {
        uint32 speed;
        uint32 attack;
        uint32 defense;
        uint32 hp;
        uint32 maxHp;
        uint32 range;
        uint32 mp;
    }

    struct CraftingState {
        uint64 startBlock;
        uint64 requiredBlocks;
        uint64 recipeId;
    }

    struct LearningState {
        uint64 startBlock;
        uint64 requiredBlocks;
        uint32 targetId;
        uint32 skillId;
        bool isNPC;
        address teacherWallet;
    }

    struct TeachingState {
        uint64 startBlock;
        uint64 requiredBlocks;
        uint32 skillId;
        address studentWallet;
    }

    struct TeleportState {
        uint64 startBlock;
        uint64 requiredBlocks;
        Position targetPosition;
    }

    struct GatheringState {
        uint64 startBlock;
        uint64 requiredBlocks;
        uint64 targetLandId;
        uint64 amount;
    }

    struct RoleData {
        Position position;
        RoleAttributes attributes;
        RoleState state;
        CraftingState crafting;
        LearningState learning;
        TeleportState teleport;
        GatheringState gathering;
        TeachingState teaching;
        mapping(uint256 => bool) skills;
        mapping(uint256 => uint256) equippedItems; // slot => equipmentId
        string nickname;
        uint8 gender;
    }

    struct ResourcePoint {
        uint64 resourceType;
        uint64 stock;
        bool isResourcePoint;
    }

    struct NPC {
        uint32 skillId;
        Position position;
        uint64 startBlock;
        bool isTeaching;
        uint160 studentId;
    }

    struct Recipe {
        uint256[] requiredResources;
        uint256[] requiredAmounts;
        uint64 requiredSkill;
        uint64 requiredBlocks;
        uint64 outputEquipmentId;
    }

    struct EquipmentConfig {
        uint32 slot; // e.g. 1: Weapon, 2: Armor, etc. (0 means not an equipment)
        int32 speedBonus;
        int32 attackBonus;
        int32 defenseBonus;
        int32 maxHpBonus;
        int32 rangeBonus;
    }

    struct GameState {
        address owner;
        address roleContract;
        address configContract;
        address economyContract;
        address randomizerContract;
        address resourceContract;
        mapping(address => RoleData) roles;
        mapping(uint256 => address) landOwners; // legacy slot kept for upgrade-safe storage layout
        mapping(uint256 => address) landContracts; // landId => custom smart contract address
        mapping(address => uint256) contractToLand; // custom smart contract address => landId
        mapping(address => bool) isLandContract; // verify if address is a registered land contract
        mapping(uint256 => ResourcePoint) resourcePoints;
        mapping(uint256 => NPC) npcs;
        mapping(uint256 => Recipe) recipes;
        mapping(uint256 => uint256) skillRequiredBlocks;
        mapping(uint256 => EquipmentConfig) equipments;
        uint256 totalRegistered;
        address landContract;
        mapping(bytes32 => address) nicknameOwners;
        uint256[33] __gap;
    }

    bytes32 constant GAME_STORAGE_POSITION = keccak256("agentbox.core.storage");

    function getStorage() internal pure returns (GameState storage gs) {
        bytes32 position = GAME_STORAGE_POSITION;
        assembly {
            gs.slot := position
        }
    }
}
