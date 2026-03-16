// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAgentboxCore {
    struct CoreContracts {
        address roleContract;
        address configContract;
        address economyContract;
        address randomizerContract;
        address resourceContract;
        address landContract;
    }

    struct GlobalConfigSnapshot {
        uint256 mapWidth;
        uint256 mapHeight;
        uint256 mintIntervalBlocks;
        uint256 mintAmount;
        uint256 stabilizationBlocks;
        uint256 craftDurationBlocks;
        uint256 halvingIntervalBlocks;
        uint256 landPrice;
    }

    struct RoleSnapshot {
        bool exists;
        uint8 state;
        uint32 x;
        uint32 y;
        uint32 speed;
        uint32 attack;
        uint32 defense;
        uint32 hp;
        uint32 maxHp;
        uint32 range;
        uint32 mp;
    }

    struct RoleProfileSnapshot {
        string nickname;
        uint8 gender;
    }

    struct RoleActionSnapshot {
        uint64 craftingStartBlock;
        uint64 craftingRequiredBlocks;
        uint64 craftingRecipeId;
        uint64 learningStartBlock;
        uint64 learningRequiredBlocks;
        uint32 learningTargetId;
        uint32 learningSkillId;
        bool learningIsNPC;
        address learningTeacherWallet;
        uint64 teachingStartBlock;
        uint64 teachingRequiredBlocks;
        uint32 teachingSkillId;
        address teachingStudentWallet;
        uint64 teleportStartBlock;
        uint64 teleportRequiredBlocks;
        uint32 teleportTargetX;
        uint32 teleportTargetY;
        uint64 gatheringStartBlock;
        uint64 gatheringRequiredBlocks;
        uint64 gatheringTargetLandId;
        uint64 gatheringAmount;
    }

    struct LandSnapshot {
        uint256 landId;
        uint256 x;
        uint256 y;
        address owner;
        address landContractAddress;
        bool isResourcePoint;
        uint64 resourceType;
        uint64 stock;
        uint256 groundTokens;
    }

    struct NpcSnapshot {
        uint32 skillId;
        uint32 x;
        uint32 y;
        uint64 startBlock;
        bool isTeaching;
        address studentWallet;
    }

    struct RecipeSnapshot {
        uint256[] requiredResources;
        uint256[] requiredAmounts;
        uint64 requiredSkill;
        uint64 requiredBlocks;
        uint64 outputEquipmentId;
    }

    struct EquipmentSnapshot {
        uint32 slot;
        int32 speedBonus;
        int32 attackBonus;
        int32 defenseBonus;
        int32 maxHpBonus;
        int32 rangeBonus;
    }

    function initialize(
        address _roleContract,
        address _configContract,
        address _economyContract,
        address _randomizerContract,
        address _resourceContract,
        address _landContract
    ) external;

    function registerCharacter(uint256 roleId) external payable;
    function registerCharacter(uint256 roleId, string calldata nickname, uint8 gender) external payable;
    function processSpawn(uint256 roleId, uint256 randomWord) external;
    function getEntityPosition(address entity) external view returns (bool isValid, uint256 x, uint256 y);
    function getCoreContracts() external view returns (CoreContracts memory snapshot);
    function getGlobalConfig() external view returns (GlobalConfigSnapshot memory snapshot);
    function getRoleIdentity(address roleWallet)
        external
        view
        returns (bool isValidRoleWallet, uint256 roleId, address owner, address controller);
    function getRoleSnapshot(address roleWallet) external view returns (RoleSnapshot memory snapshot);
    function getRoleProfile(address roleWallet) external view returns (RoleProfileSnapshot memory snapshot);
    function getRoleWalletByNickname(string calldata nickname) external view returns (address roleWallet);
    function getRoleActionSnapshot(address roleWallet) external view returns (RoleActionSnapshot memory snapshot);
    function getRoleSkill(address roleWallet, uint256 skillId) external view returns (bool hasSkill);
    function getRoleSkills(address roleWallet, uint256[] calldata skillIds) external view returns (bool[] memory skills);
    function getEquipped(address roleWallet, uint256 slot) external view returns (uint256 equipmentId);
    function getEquippedBatch(address roleWallet, uint256[] calldata slots) external view returns (uint256[] memory equipped);
    function getLandSnapshot(uint256 x, uint256 y) external view returns (LandSnapshot memory snapshot);
    function getLandSnapshotById(uint256 landId) external view returns (LandSnapshot memory snapshot);
    function getNpcSnapshot(uint256 npcId) external view returns (NpcSnapshot memory snapshot);
    function getRecipeSnapshot(uint256 recipeId) external view returns (RecipeSnapshot memory snapshot);
    function getEquipmentSnapshot(uint256 equipmentId) external view returns (EquipmentSnapshot memory snapshot);
    function getSkillRequiredBlocks(uint256 skillId) external view returns (uint256 requiredBlocks);
    function getEconomyBalances(address account)
        external
        view
        returns (uint256 totalBalance, uint256 unreliableBalance, uint256 reliableBalance);
    function canFinishCurrentAction(address roleWallet)
        external
        view
        returns (bool canFinish, uint8 state, uint256 finishBlock);
    
    function move(address roleWallet, int256 dx, int256 dy) external;
    function startTeleport(address roleWallet, uint256 targetX, uint256 targetY) external;
    function finishTeleport(address roleWallet) external;
    function attack(address roleWallet, address targetWallet) external;
    function processRespawn(uint256 roleId, uint256 randomWord) external;

    function withdrawEth() external;
    function setResourcePoint(uint256 x, uint256 y, uint256 resourceType, uint256 initialStock) external;
    function setSkillBlocks(uint256 skillId, uint256 requiredBlocks) external;
    function setNPC(uint256 npcId, uint256 x, uint256 y, uint256 skillId) external;
    function setRecipe(uint256 recipeId, uint256[] calldata resourceTypes, uint256[] calldata amounts, uint256 skillId, uint256 requiredBlocks, uint256 outputEqId) external;
    function setEquipmentConfig(uint256 equipmentId, uint256 slot, int256 speedBonus, int256 attackBonus, int256 defenseBonus, int256 maxHpBonus, int256 rangeBonus) external;

    event CoreContractsUpdated(
        address roleContract,
        address configContract,
        address economyContract,
        address randomizerContract,
        address resourceContract,
        address landContract
    );
    event CharacterProfileSet(address indexed roleWallet, string nickname, uint8 gender);
    event ActionStarted(address indexed roleWallet, string actionType);
    event ActionFinished(address indexed roleWallet, string actionType);
    event RoleMoved(address indexed roleWallet, uint256 x, uint256 y);
    event Attacked(address indexed attacker, address indexed target, uint256 damage);
    event Equipped(address indexed roleWallet, uint256 slot, uint256 equipmentId);
    event SkillLearned(
        address indexed roleWallet,
        uint256 indexed skillId,
        bool learnedFromNpc,
        uint256 targetId,
        address teacherWallet
    );
    event NPCTeachingStateChanged(
        uint256 indexed npcId,
        bool isTeaching,
        address studentWallet,
        uint256 startBlock
    );
    event ResourcePointUpdated(
        uint256 indexed landId,
        uint256 indexed x,
        uint256 indexed y,
        uint256 resourceType,
        uint256 stock,
        bool isResourcePoint
    );
    event RoleRespawned(address indexed roleWallet, uint256 x, uint256 y, uint256 hp);
    event ResourcePointSet(
        uint256 indexed landId, uint256 indexed x, uint256 indexed y, uint256 resourceType, uint256 initialStock
    );
    event SkillBlocksSet(uint256 indexed skillId, uint256 requiredBlocks);
    event NPCSet(uint256 indexed npcId, uint256 indexed x, uint256 indexed y, uint256 skillId);
    event NPCRefreshed(uint256 indexed npcId, uint256 indexed x, uint256 indexed y, uint256 skillId);
    event RecipeSet(
        uint256 indexed recipeId,
        uint256[] resourceTypes,
        uint256[] amounts,
        uint256 skillId,
        uint256 requiredBlocks,
        uint256 outputEqId
    );
    event EquipmentConfigSet(
        uint256 indexed equipmentId,
        uint256 indexed slot,
        int256 speedBonus,
        int256 attackBonus,
        int256 defenseBonus,
        int256 maxHpBonus,
        int256 rangeBonus
    );

    function gather(address roleWallet) external;
    function startGather(address roleWallet, uint256 amount) external;
    function finishGather(address roleWallet) external;
    function startCrafting(address roleWallet, uint256 recipeId) external;
    function finishCrafting(address roleWallet) external;
    function equip(address roleWallet, uint256 equipmentId) external;
    function unequip(address roleWallet, uint256 slot) external;

    function startLearning(address roleWallet, uint256 npcId) external;
    function requestLearningFromPlayer(address roleWallet, address teacherWallet, uint256 skillId) external;
    function acceptTeaching(address roleWallet, address studentWallet) external;
    function cancelLearning(address roleWallet) external;
    function cancelTeaching(address roleWallet) external;
    function finishLearning(address roleWallet) external;
    function processNPCRefresh(uint256 npcId, uint256 randomWord) external;

    function buyLand(address roleWallet, uint256 x, uint256 y) external;
    function sellLand(address roleWallet, uint256 x, uint256 y) external;
    function setLandContract(address roleWallet, uint256 x, uint256 y, address contractAddress) external;

    function sendMessage(address roleWallet, address toWallet, string calldata message) external;
    function sendGlobalMessage(address roleWallet, string calldata message) external;
}
