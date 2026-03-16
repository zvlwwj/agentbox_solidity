// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Errors.sol";

import "./AgentboxBase.sol";
import "../AgentboxConfig.sol";

contract AdminFacet is AgentboxBase {
    event ResourcePointSet(
        uint256 indexed landId, uint256 indexed x, uint256 indexed y, uint256 resourceType, uint256 initialStock
    );
    event SkillBlocksSet(uint256 indexed skillId, uint256 requiredBlocks);
    event NPCSet(uint256 indexed npcId, uint256 indexed x, uint256 indexed y, uint256 skillId);
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

    function initialize(
        address _roleContract,
        address _configContract,
        address _economyContract,
        address _randomizerContract,
        address _resourceContract,
        address _landContract
    ) external onlyOwner {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        state.roleContract = _roleContract;
        state.configContract = _configContract;
        state.economyContract = _economyContract;
        state.randomizerContract = _randomizerContract;
        state.resourceContract = _resourceContract;
        state.landContract = _landContract;

        emit CoreContractsUpdated(
            _roleContract,
            _configContract,
            _economyContract,
            _randomizerContract,
            _resourceContract,
            _landContract
        );
    }

    function withdrawEth() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
    }

    function setResourcePoint(uint256 x, uint256 y, uint256 resourceType, uint256 initialStock) external onlyOwner {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 landId = y * config.mapWidth() + x;
        state.resourcePoints[landId] =
            AgentboxStorage.ResourcePoint({resourceType: uint64(resourceType), stock: uint64(initialStock), isResourcePoint: true});
        emit ResourcePointSet(landId, x, y, resourceType, initialStock);
    }

    function setSkillBlocks(uint256 skillId, uint256 requiredBlocks) external onlyOwner {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        state.skillRequiredBlocks[skillId] = requiredBlocks;
        emit SkillBlocksSet(skillId, requiredBlocks);
    }

    function setNPC(uint256 npcId, uint256 x, uint256 y, uint256 skillId) external onlyOwner {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.NPC storage npc = state.npcs[npcId];
        npc.position.x = uint32(x);
        npc.position.y = uint32(y);
        npc.skillId = uint32(skillId);
        emit NPCSet(npcId, x, y, skillId);
    }

    function setRecipe(
        uint256 recipeId,
        uint256[] calldata resourceTypes,
        uint256[] calldata amounts,
        uint256 skillId,
        uint256 requiredBlocks,
        uint256 outputEqId
    ) external onlyOwner {
        if (!(resourceTypes.length == amounts.length)) revert MismatchedArrays();
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        state.recipes[recipeId] = AgentboxStorage.Recipe({
            requiredResources: resourceTypes,
            requiredAmounts: amounts,
            requiredSkill: uint64(skillId),
            requiredBlocks: uint64(requiredBlocks),
            outputEquipmentId: uint64(outputEqId)
        });
        emit RecipeSet(recipeId, resourceTypes, amounts, skillId, requiredBlocks, outputEqId);
    }

    function setEquipmentConfig(
        uint256 equipmentId,
        uint256 slot,
        int256 speedBonus,
        int256 attackBonus,
        int256 defenseBonus,
        int256 maxHpBonus,
        int256 rangeBonus
    ) external onlyOwner {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        state.equipments[equipmentId] = AgentboxStorage.EquipmentConfig({
            slot: uint32(slot),
            speedBonus: int32(speedBonus),
            attackBonus: int32(attackBonus),
            defenseBonus: int32(defenseBonus),
            maxHpBonus: int32(maxHpBonus),
            rangeBonus: int32(rangeBonus)
        });
        emit EquipmentConfigSet(equipmentId, slot, speedBonus, attackBonus, defenseBonus, maxHpBonus, rangeBonus);
    }
}
