// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/interfaces/IAgentboxCore.sol";
import "../src/AgentboxConfig.sol";

contract InitGameScript is Script {
    struct ResourcePointConfig {
        uint256 x;
        uint256 y;
        uint256 resourceType;
        uint256 initialStock;
    }

    struct SkillConfig {
        uint256 skillId;
        uint256 requiredBlocks;
    }

    struct NPCConfig {
        uint256 npcId;
        uint256 x;
        uint256 y;
        uint256 skillId;
    }

    struct RecipeConfig {
        uint256 recipeId;
        uint256[] resourceTypes;
        uint256[] amounts;
        uint256 skillId;
        uint256 requiredBlocks;
        uint256 outputEqId;
    }

    struct EquipmentConfig {
        uint256 equipmentId;
        uint256 slot;
        int256 speedBonus;
        int256 attackBonus;
        int256 defenseBonus;
        int256 maxHpBonus;
        int256 rangeBonus;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address coreAddress = vm.envAddress("CORE_ADDRESS");
        address configAddress = vm.envAddress("CONFIG_ADDRESS");

        IAgentboxCore core = IAgentboxCore(coreAddress);
        AgentboxConfig config = AgentboxConfig(configAddress);

        vm.startBroadcast(deployerPrivateKey);

        _initGlobalConfig(config);
        _initGameContent(core);

        vm.stopBroadcast();

        console.log("=== Game Initialization Successful ===");
        console.log("Core:", coreAddress);
        console.log("Config:", configAddress);
        console.log("=====================================");
    }

    function _initGlobalConfig(AgentboxConfig config) internal {
        uint256 mapWidth = vm.envOr("GAME_MAP_WIDTH", config.mapWidth());
        uint256 mapHeight = vm.envOr("GAME_MAP_HEIGHT", config.mapHeight());
        uint256 mintInterval = vm.envOr("GAME_MINT_INTERVAL_BLOCKS", config.mintIntervalBlocks());
        uint256 mintAmount = vm.envOr("GAME_MINT_AMOUNT", config.mintAmount());
        uint256 stabilizationBlocks = vm.envOr("GAME_STABILIZATION_BLOCKS", config.stabilizationBlocks());
        uint256 craftDurationBlocks = vm.envOr("GAME_CRAFT_DURATION_BLOCKS", config.craftDurationBlocks());
        uint256 halvingIntervalBlocks = vm.envOr("GAME_HALVING_INTERVAL_BLOCKS", config.halvingIntervalBlocks());
        uint256 landPrice = vm.envOr("GAME_LAND_PRICE", config.landPrice());

        config.setMapDimensions(mapWidth, mapHeight);
        config.setMintIntervalBlocks(mintInterval);
        config.setMintAmount(mintAmount);
        config.setStabilizationBlocks(stabilizationBlocks);
        config.setCraftDurationBlocks(craftDurationBlocks);
        config.setHalvingIntervalBlocks(halvingIntervalBlocks);
        config.setLandPrice(landPrice);
    }

    function _initGameContent(IAgentboxCore core) internal {
        ResourcePointConfig[] memory resourcePoints = _defaultResourcePoints();
        for (uint256 i = 0; i < resourcePoints.length; i++) {
            ResourcePointConfig memory p = resourcePoints[i];
            core.setResourcePoint(p.x, p.y, p.resourceType, p.initialStock);
        }

        SkillConfig[] memory skills = _defaultSkills();
        for (uint256 i = 0; i < skills.length; i++) {
            SkillConfig memory s = skills[i];
            core.setSkillBlocks(s.skillId, s.requiredBlocks);
        }

        NPCConfig[] memory npcs = _defaultNPCs();
        for (uint256 i = 0; i < npcs.length; i++) {
            NPCConfig memory n = npcs[i];
            core.setNPC(n.npcId, n.x, n.y, n.skillId);
        }

        RecipeConfig[] memory recipes = _defaultRecipes();
        for (uint256 i = 0; i < recipes.length; i++) {
            RecipeConfig memory r = recipes[i];
            core.setRecipe(r.recipeId, r.resourceTypes, r.amounts, r.skillId, r.requiredBlocks, r.outputEqId);
        }

        EquipmentConfig[] memory eqs = _defaultEquipments();
        for (uint256 i = 0; i < eqs.length; i++) {
            EquipmentConfig memory e = eqs[i];
            core.setEquipmentConfig(
                e.equipmentId,
                e.slot,
                e.speedBonus,
                e.attackBonus,
                e.defenseBonus,
                e.maxHpBonus,
                e.rangeBonus
            );
        }
    }

    function _defaultResourcePoints() internal pure returns (ResourcePointConfig[] memory points) {
        points = new ResourcePointConfig[](3);
        points[0] = ResourcePointConfig({x: 10, y: 10, resourceType: 1, initialStock: 1000});
        points[1] = ResourcePointConfig({x: 12, y: 10, resourceType: 2, initialStock: 800});
        points[2] = ResourcePointConfig({x: 15, y: 15, resourceType: 3, initialStock: 500});
    }

    function _defaultSkills() internal pure returns (SkillConfig[] memory skills) {
        skills = new SkillConfig[](3);
        skills[0] = SkillConfig({skillId: 1, requiredBlocks: 300});
        skills[1] = SkillConfig({skillId: 2, requiredBlocks: 600});
        skills[2] = SkillConfig({skillId: 3, requiredBlocks: 900});
    }

    function _defaultNPCs() internal pure returns (NPCConfig[] memory npcs) {
        npcs = new NPCConfig[](3);
        npcs[0] = NPCConfig({npcId: 1, x: 50, y: 50, skillId: 1});
        npcs[1] = NPCConfig({npcId: 2, x: 60, y: 50, skillId: 2});
        npcs[2] = NPCConfig({npcId: 3, x: 70, y: 50, skillId: 3});
    }

    function _defaultRecipes() internal pure returns (RecipeConfig[] memory recipes) {
        recipes = new RecipeConfig[](2);

        uint256[] memory recipe1Types = new uint256[](2);
        recipe1Types[0] = 1;
        recipe1Types[1] = 2;
        uint256[] memory recipe1Amounts = new uint256[](2);
        recipe1Amounts[0] = 10;
        recipe1Amounts[1] = 5;
        recipes[0] = RecipeConfig({
            recipeId: 1,
            resourceTypes: recipe1Types,
            amounts: recipe1Amounts,
            skillId: 1,
            requiredBlocks: 300,
            outputEqId: 1001
        });

        uint256[] memory recipe2Types = new uint256[](2);
        recipe2Types[0] = 2;
        recipe2Types[1] = 3;
        uint256[] memory recipe2Amounts = new uint256[](2);
        recipe2Amounts[0] = 12;
        recipe2Amounts[1] = 6;
        recipes[1] = RecipeConfig({
            recipeId: 2,
            resourceTypes: recipe2Types,
            amounts: recipe2Amounts,
            skillId: 2,
            requiredBlocks: 500,
            outputEqId: 1002
        });
    }

    function _defaultEquipments() internal pure returns (EquipmentConfig[] memory equipments) {
        equipments = new EquipmentConfig[](2);
        equipments[0] = EquipmentConfig({
            equipmentId: 1001,
            slot: 1,
            speedBonus: 1,
            attackBonus: 2,
            defenseBonus: 0,
            maxHpBonus: 10,
            rangeBonus: 0
        });
        equipments[1] = EquipmentConfig({
            equipmentId: 1002,
            slot: 2,
            speedBonus: 0,
            attackBonus: 3,
            defenseBonus: 1,
            maxHpBonus: 20,
            rangeBonus: 1
        });
    }
}
