// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Errors.sol";

import "./AgentboxBase.sol";
import "../AgentboxConfig.sol";

contract AdminFacet is AgentboxBase {
    function initialize(
        address _roleContract,
        address _configContract,
        address _economyContract,
        address _randomizerContract,
        address _resourceContract
    ) external onlyOwner {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        state.roleContract = _roleContract;
        state.configContract = _configContract;
        state.economyContract = _economyContract;
        state.randomizerContract = _randomizerContract;
        state.resourceContract = _resourceContract;
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
    }

    function setSkillBlocks(uint256 skillId, uint256 requiredBlocks) external onlyOwner {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        state.skillRequiredBlocks[skillId] = requiredBlocks;
    }

    function setNPC(uint256 npcId, uint256 x, uint256 y, uint256 skillId) external onlyOwner {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.NPC storage npc = state.npcs[npcId];
        npc.position.x = uint32(x);
        npc.position.y = uint32(y);
        npc.skillId = uint32(skillId);
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
    }
}