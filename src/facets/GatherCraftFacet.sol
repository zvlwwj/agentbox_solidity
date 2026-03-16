// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Errors.sol";

import "./AgentboxBase.sol";
import "../AgentboxConfig.sol";
import "../AgentboxResource.sol";

contract GatherCraftFacet is AgentboxBase {
    function gather(address roleWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        if (!(role.state == AgentboxStorage.RoleState.Idle)) revert RoleNotIdle();

        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 landId = role.position.y * config.mapWidth() + role.position.x;
        AgentboxStorage.ResourcePoint storage rp = state.resourcePoints[landId];

        if (!(rp.isResourcePoint)) revert NotAResourcePoint();
        if (!(rp.stock > 0)) revert ResourceDepleted();
        if (!(role.skills[rp.resourceType])) revert MissingRequiredSkill();

        uint256 gatherAmount = 1;

        if (rp.stock < gatherAmount) {
            gatherAmount = rp.stock;
        }

        rp.stock -= uint64(gatherAmount);
        
        if (state.resourceContract != address(0)) {
            AgentboxResource(state.resourceContract).mint(roleWallet, rp.resourceType, gatherAmount, "");
        }

        if (rp.stock == 0) {
            rp.isResourcePoint = false;
        }

        emit ResourcePointUpdated(landId, role.position.x, role.position.y, rp.resourceType, rp.stock, rp.isResourcePoint);
    }

    function startGather(address roleWallet, uint256 amount) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        if (!(role.state == AgentboxStorage.RoleState.Idle)) revert RoleNotIdle();

        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 landId = role.position.y * config.mapWidth() + role.position.x;
        AgentboxStorage.ResourcePoint storage rp = state.resourcePoints[landId];

        if (!(rp.isResourcePoint)) revert NotAResourcePoint();
        if (!(rp.stock >= amount)) revert NotEnoughResourceStock();
        if (!(role.skills[rp.resourceType])) revert MissingRequiredSkill();

        uint256 blocksPerResource = 2; // Fixed blocks per resource
        uint256 requiredBlocks = amount * blocksPerResource;

        rp.stock -= uint64(amount);
        if (rp.stock == 0) {
            rp.isResourcePoint = false;
        }

        emit ResourcePointUpdated(landId, role.position.x, role.position.y, rp.resourceType, rp.stock, rp.isResourcePoint);

        role.state = AgentboxStorage.RoleState.Gathering;
        role.gathering = AgentboxStorage.GatheringState({
            startBlock: uint64(block.number),
            requiredBlocks: uint64(requiredBlocks),
            targetLandId: uint64(landId),
            amount: uint64(amount)
        });

        emit ActionStarted(roleWallet, "Gather");
    }

    function finishGather(address roleWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];

        if (!(role.state == AgentboxStorage.RoleState.Gathering)) revert RoleNotGathering();
        if (!(block.number >= role.gathering.startBlock + role.gathering.requiredBlocks)) revert GatheringNotFinishedYet();

        uint256 targetLandId = role.gathering.targetLandId;
        AgentboxStorage.ResourcePoint storage rp = state.resourcePoints[targetLandId];

        role.state = AgentboxStorage.RoleState.Idle;

        if (state.resourceContract != address(0)) {
            AgentboxResource(state.resourceContract).mint(roleWallet, rp.resourceType, role.gathering.amount, "");
        }

        emit ActionFinished(roleWallet, "Gather");
    }

    function startCrafting(address roleWallet, uint256 recipeId) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        if (!(role.state == AgentboxStorage.RoleState.Idle)) revert RoleNotIdle();

        AgentboxStorage.Recipe storage recipe = state.recipes[recipeId];
        if (!(recipe.outputEquipmentId != 0)) revert InvalidRecipe();
        if (!(role.skills[recipe.requiredSkill])) revert MissingRequiredSkill();
        
        // Verify balances and deduct resources
        for (uint256 i = 0; i < recipe.requiredResources.length; i++) {
            uint256 resId = recipe.requiredResources[i];
            uint256 amt = recipe.requiredAmounts[i];
            require(AgentboxResource(state.resourceContract).balanceOf(roleWallet, resId) >= amt, "Not enough resources");
            AgentboxResource(state.resourceContract).burn(roleWallet, resId, amt);
        }

        // Set state
        role.state = AgentboxStorage.RoleState.Crafting;
        role.crafting = AgentboxStorage.CraftingState({
            startBlock: uint64(block.number),
            requiredBlocks: recipe.requiredBlocks,
            recipeId: uint64(recipeId)
        });

        emit ActionStarted(roleWallet, "Craft");
    }

    function finishCrafting(address roleWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        if (!(role.state == AgentboxStorage.RoleState.Crafting)) revert NotCrafting();
        if (!(block.number >= role.crafting.startBlock + role.crafting.requiredBlocks)) revert CraftingNotFinished();

        AgentboxStorage.Recipe storage recipe = state.recipes[role.crafting.recipeId];

        // Output equipment
        AgentboxResource(state.resourceContract).mint(roleWallet, recipe.outputEquipmentId, 1, "");
        role.state = AgentboxStorage.RoleState.Idle;

        emit ActionFinished(roleWallet, "Craft");
    }

    function equip(address roleWallet, uint256 equipmentId) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        if (!(role.state == AgentboxStorage.RoleState.Idle)) revert RoleNotIdle();

        AgentboxStorage.EquipmentConfig storage config = state.equipments[equipmentId];
        if (!(config.slot > 0)) revert NotAnEquipment();

        // Verify balance
        require(AgentboxResource(state.resourceContract).balanceOf(roleWallet, equipmentId) > 0, "Do not own equipment");

        uint256 slot = config.slot;
        uint256 currentEq = role.equippedItems[slot];

        if (currentEq != 0) {
            _removeEquipmentStats(role, state.equipments[currentEq]);
            // return currentEq to inventory
            AgentboxResource(state.resourceContract).mint(roleWallet, currentEq, 1, "");
        }

        // burn the newly equipped item from inventory
        AgentboxResource(state.resourceContract).burn(roleWallet, equipmentId, 1);
        
        role.equippedItems[slot] = equipmentId;
        _applyEquipmentStats(role, config);
        
        emit Equipped(roleWallet, slot, equipmentId);
    }

    function unequip(address roleWallet, uint256 slot) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        if (!(role.state == AgentboxStorage.RoleState.Idle)) revert RoleNotIdle();

        uint256 currentEq = role.equippedItems[slot];
        if (!(currentEq != 0)) revert NothingEquippedInSlot();

        role.equippedItems[slot] = 0;
        _removeEquipmentStats(role, state.equipments[currentEq]);

        // return item to inventory
        AgentboxResource(state.resourceContract).mint(roleWallet, currentEq, 1, "");
        
        emit Equipped(roleWallet, slot, 0); // 0 means unequipped
    }

    function _applyEquipmentStats(AgentboxStorage.RoleData storage role, AgentboxStorage.EquipmentConfig memory config) internal {
        role.attributes.speed = uint32(_addIntToUint(role.attributes.speed, config.speedBonus));
        role.attributes.attack = uint32(_addIntToUint(role.attributes.attack, config.attackBonus));
        role.attributes.defense = uint32(_addIntToUint(role.attributes.defense, config.defenseBonus));
        role.attributes.maxHp = uint32(_addIntToUint(role.attributes.maxHp, config.maxHpBonus));
        role.attributes.range = uint32(_addIntToUint(role.attributes.range, config.rangeBonus));
    }

    function _removeEquipmentStats(AgentboxStorage.RoleData storage role, AgentboxStorage.EquipmentConfig memory config) internal {
        role.attributes.speed = uint32(_addIntToUint(role.attributes.speed, -config.speedBonus));
        role.attributes.attack = uint32(_addIntToUint(role.attributes.attack, -config.attackBonus));
        role.attributes.defense = uint32(_addIntToUint(role.attributes.defense, -config.defenseBonus));
        role.attributes.maxHp = uint32(_addIntToUint(role.attributes.maxHp, -config.maxHpBonus));
        role.attributes.range = uint32(_addIntToUint(role.attributes.range, -config.rangeBonus));

        if (role.attributes.hp > role.attributes.maxHp) {
            role.attributes.hp = role.attributes.maxHp;
        }
    }

    function _addIntToUint(uint256 a, int256 b) internal pure returns (uint256) {
        if (b < 0) {
            uint256 absB = uint256(-b);
            return a > absB ? a - absB : 0;
        } else {
            return a + uint256(b);
        }
    }
}
