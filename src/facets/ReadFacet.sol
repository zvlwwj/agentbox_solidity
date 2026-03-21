// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AgentboxBase.sol";
import "../AgentboxConfig.sol";
import "../AgentboxEconomy.sol";
import "../AgentboxLand.sol";

contract ReadFacet is AgentboxBase {
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
        uint256 maxMintCount;
        uint256 stabilizationBlocks;
        uint256 craftDurationBlocks;
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
        uint32 gatheringResourceType;
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

    function getCoreContracts() external view returns (CoreContracts memory snapshot) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        snapshot = CoreContracts({
            roleContract: state.roleContract,
            configContract: state.configContract,
            economyContract: state.economyContract,
            randomizerContract: state.randomizerContract,
            resourceContract: state.resourceContract,
            landContract: state.landContract
        });
    }

    function getGlobalConfig() external view returns (GlobalConfigSnapshot memory snapshot) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxConfig config = AgentboxConfig(state.configContract);
        snapshot = GlobalConfigSnapshot({
            mapWidth: config.mapWidth(),
            mapHeight: config.mapHeight(),
            mintIntervalBlocks: config.mintIntervalBlocks(),
            mintAmount: config.mintAmount(),
            maxMintCount: config.maxMintCount(),
            stabilizationBlocks: config.stabilizationBlocks(),
            craftDurationBlocks: config.craftDurationBlocks(),
            landPrice: config.landPrice()
        });
    }

    function getRoleIdentity(address roleWallet)
        external
        view
        returns (bool isValidRoleWallet, uint256 roleId, address owner, address controller)
    {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxRole roleToken = AgentboxRole(state.roleContract);

        try AgentboxRoleWallet(payable(roleWallet)).roleId() returns (uint256 rid) {
            if (roleToken.wallets(rid) == roleWallet) {
                return (true, rid, roleToken.ownerOf(rid), roleToken.controllerOf(rid));
            }
            return (false, rid, address(0), address(0));
        } catch {
            return (false, 0, address(0), address(0));
        }
    }

    function getRoleSnapshot(address roleWallet) external view returns (RoleSnapshot memory snapshot) {
        AgentboxStorage.RoleData storage role = AgentboxStorage.getStorage().roles[roleWallet];
        snapshot = RoleSnapshot({
            exists: role.state == AgentboxStorage.RoleState.PendingSpawn || role.attributes.maxHp > 0,
            state: uint8(role.state),
            x: role.position.x,
            y: role.position.y,
            speed: role.attributes.speed,
            attack: role.attributes.attack,
            defense: role.attributes.defense,
            hp: role.attributes.hp,
            maxHp: role.attributes.maxHp,
            range: role.attributes.range,
            mp: role.attributes.mp
        });
    }

    function getRoleProfile(address roleWallet) external view returns (RoleProfileSnapshot memory snapshot) {
        AgentboxStorage.RoleData storage role = AgentboxStorage.getStorage().roles[roleWallet];
        snapshot = RoleProfileSnapshot({nickname: role.nickname, gender: role.gender});
    }

    function getRoleWalletByNickname(string calldata nickname) external view returns (address roleWallet) {
        roleWallet = AgentboxStorage.getStorage().nicknameOwners[keccak256(bytes(nickname))];
    }

    function getRoleActionSnapshot(address roleWallet) external view returns (RoleActionSnapshot memory snapshot) {
        AgentboxStorage.RoleData storage role = AgentboxStorage.getStorage().roles[roleWallet];
        snapshot = RoleActionSnapshot({
            craftingStartBlock: role.crafting.startBlock,
            craftingRequiredBlocks: role.crafting.requiredBlocks,
            craftingRecipeId: role.crafting.recipeId,
            learningStartBlock: role.learning.startBlock,
            learningRequiredBlocks: role.learning.requiredBlocks,
            learningTargetId: role.learning.targetId,
            learningSkillId: role.learning.skillId,
            learningIsNPC: role.learning.isNPC,
            learningTeacherWallet: role.learning.teacherWallet,
            teachingStartBlock: role.teaching.startBlock,
            teachingRequiredBlocks: role.teaching.requiredBlocks,
            teachingSkillId: role.teaching.skillId,
            teachingStudentWallet: role.teaching.studentWallet,
            teleportStartBlock: role.teleport.startBlock,
            teleportRequiredBlocks: role.teleport.requiredBlocks,
            teleportTargetX: role.teleport.targetPosition.x,
            teleportTargetY: role.teleport.targetPosition.y,
            gatheringStartBlock: role.gathering.startBlock,
            gatheringRequiredBlocks: role.gathering.requiredBlocks,
            gatheringTargetLandId: role.gathering.targetLandId,
            gatheringResourceType: role.gathering.resourceType,
            gatheringAmount: role.gathering.amount
        });
    }

    function getRoleSkill(address roleWallet, uint256 skillId) external view returns (bool hasSkill) {
        hasSkill = AgentboxStorage.getStorage().roles[roleWallet].skills[skillId];
    }

    function getRoleSkills(address roleWallet, uint256[] calldata skillIds) external view returns (bool[] memory skills) {
        AgentboxStorage.RoleData storage role = AgentboxStorage.getStorage().roles[roleWallet];
        skills = new bool[](skillIds.length);
        for (uint256 i = 0; i < skillIds.length; i++) {
            skills[i] = role.skills[skillIds[i]];
        }
    }

    function getEquipped(address roleWallet, uint256 slot) external view returns (uint256 equipmentId) {
        equipmentId = AgentboxStorage.getStorage().roles[roleWallet].equippedItems[slot];
    }

    function getEquippedBatch(address roleWallet, uint256[] calldata slots) external view returns (uint256[] memory equipped) {
        AgentboxStorage.RoleData storage role = AgentboxStorage.getStorage().roles[roleWallet];
        equipped = new uint256[](slots.length);
        for (uint256 i = 0; i < slots.length; i++) {
            equipped[i] = role.equippedItems[slots[i]];
        }
    }

    function getLandSnapshot(uint256 x, uint256 y) external view returns (LandSnapshot memory snapshot) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 mapWidth = config.mapWidth();
        uint256 landId = y * mapWidth + x;
        AgentboxStorage.ResourcePoint storage rp = state.resourcePoints[landId];

        snapshot = LandSnapshot({
            landId: landId,
            x: x,
            y: y,
            owner: _landOwner(state.landContract, landId),
            landContractAddress: state.landContracts[landId],
            isResourcePoint: rp.isResourcePoint,
            resourceType: rp.resourceType,
            stock: rp.stock,
            groundTokens: _groundTokens(state.economyContract, landId)
        });
    }

    function getLandSnapshotById(uint256 landId) external view returns (LandSnapshot memory snapshot) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 mapWidth = config.mapWidth();
        uint256 x = landId % mapWidth;
        uint256 y = landId / mapWidth;
        AgentboxStorage.ResourcePoint storage rp = state.resourcePoints[landId];

        snapshot = LandSnapshot({
            landId: landId,
            x: x,
            y: y,
            owner: _landOwner(state.landContract, landId),
            landContractAddress: state.landContracts[landId],
            isResourcePoint: rp.isResourcePoint,
            resourceType: rp.resourceType,
            stock: rp.stock,
            groundTokens: _groundTokens(state.economyContract, landId)
        });
    }

    function getNpcSnapshot(uint256 npcId) external view returns (NpcSnapshot memory snapshot) {
        AgentboxStorage.NPC storage npc = AgentboxStorage.getStorage().npcs[npcId];
        snapshot = NpcSnapshot({
            skillId: npc.skillId,
            x: npc.position.x,
            y: npc.position.y,
            startBlock: npc.startBlock,
            isTeaching: npc.isTeaching,
            studentWallet: address(uint160(npc.studentId))
        });
    }

    function getRecipeSnapshot(uint256 recipeId) external view returns (RecipeSnapshot memory snapshot) {
        AgentboxStorage.Recipe storage recipe = AgentboxStorage.getStorage().recipes[recipeId];
        snapshot = RecipeSnapshot({
            requiredResources: recipe.requiredResources,
            requiredAmounts: recipe.requiredAmounts,
            requiredSkill: recipe.requiredSkill,
            requiredBlocks: recipe.requiredBlocks,
            outputEquipmentId: recipe.outputEquipmentId
        });
    }

    function getEquipmentSnapshot(uint256 equipmentId) external view returns (EquipmentSnapshot memory snapshot) {
        AgentboxStorage.EquipmentConfig storage eq = AgentboxStorage.getStorage().equipments[equipmentId];
        snapshot = EquipmentSnapshot({
            slot: eq.slot,
            speedBonus: eq.speedBonus,
            attackBonus: eq.attackBonus,
            defenseBonus: eq.defenseBonus,
            maxHpBonus: eq.maxHpBonus,
            rangeBonus: eq.rangeBonus
        });
    }

    function getSkillRequiredBlocks(uint256 skillId) external view returns (uint256 requiredBlocks) {
        requiredBlocks = AgentboxStorage.getStorage().skillRequiredBlocks[skillId];
    }

    function getEconomyBalances(address account)
        external
        view
        returns (uint256 totalBalance, uint256 unreliableBalance, uint256 reliableBalance)
    {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        if (state.economyContract == address(0)) {
            return (0, 0, 0);
        }

        AgentboxEconomy economy = AgentboxEconomy(state.economyContract);
        totalBalance = economy.balanceOf(account);
        unreliableBalance = economy.unreliableBalanceOf(account);
        reliableBalance = totalBalance > unreliableBalance ? totalBalance - unreliableBalance : 0;
    }

    function canFinishCurrentAction(address roleWallet)
        external
        view
        returns (bool canFinish, uint8 state, uint256 finishBlock)
    {
        AgentboxStorage.RoleData storage role = AgentboxStorage.getStorage().roles[roleWallet];
        state = uint8(role.state);

        if (role.state == AgentboxStorage.RoleState.Teleporting) {
            finishBlock = role.teleport.startBlock + role.teleport.requiredBlocks;
            canFinish = block.number >= finishBlock;
        } else if (role.state == AgentboxStorage.RoleState.Gathering) {
            finishBlock = role.gathering.startBlock + role.gathering.requiredBlocks;
            canFinish = block.number >= finishBlock;
        } else if (role.state == AgentboxStorage.RoleState.Crafting) {
            finishBlock = role.crafting.startBlock + role.crafting.requiredBlocks;
            canFinish = block.number >= finishBlock;
        } else if (role.state == AgentboxStorage.RoleState.Learning && role.learning.startBlock != 0) {
            finishBlock = role.learning.startBlock + role.learning.requiredBlocks;
            canFinish = block.number >= finishBlock;
        }
    }

    function _groundTokens(address economyContract, uint256 landId) internal view returns (uint256 amount) {
        if (economyContract == address(0)) {
            return 0;
        }
        amount = AgentboxEconomy(economyContract).groundTokens(landId);
    }

    function _landOwner(address landContract, uint256 landId) internal view returns (address owner) {
        if (landContract == address(0)) {
            return address(0);
        }
        try AgentboxLand(landContract).ownerOf(landId) returns (address currentOwner) {
            return currentOwner;
        } catch {
            return address(0);
        }
    }
}
