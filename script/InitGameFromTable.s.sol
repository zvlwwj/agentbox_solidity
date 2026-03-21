// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/interfaces/IAgentboxCore.sol";
import "../src/AgentboxConfig.sol";

contract InitGameFromTableScript is Script {
    struct GlobalConfig {
        uint256 mapWidth;
        uint256 mapHeight;
        uint256 mintIntervalBlocks;
        uint256 mintAmount;
        uint256 maxMintCount;
        uint256 stabilizationBlocks;
        uint256 craftDurationBlocks;
        uint256 landPrice;
    }

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
        string memory paramsFile = vm.envOr("INIT_PARAMS_FILE", string("docs/game-init-params.json"));

        string memory json = vm.readFile(paramsFile);
        GlobalConfig memory globalConfig = _parseGlobalConfig(json);
        ResourcePointConfig[] memory resourcePoints = _parseResourcePoints(json);
        SkillConfig[] memory skills = _parseSkills(json);
        NPCConfig[] memory npcs = _parseNpcs(json);
        RecipeConfig[] memory recipes = _parseRecipes(json);
        EquipmentConfig[] memory equipments = _parseEquipments(json);

        IAgentboxCore core = IAgentboxCore(coreAddress);
        AgentboxConfig config = AgentboxConfig(configAddress);

        vm.startBroadcast(deployerPrivateKey);
        _initGlobalConfig(config, globalConfig);
        _initGameContent(core, resourcePoints, skills, npcs, recipes, equipments);
        vm.stopBroadcast();

        console.log("=== Game Init From Table Successful ===");
        console.log("Core:", coreAddress);
        console.log("Config:", configAddress);
        console.log("Params file:", paramsFile);
        console.log("=======================================");
    }

    function _parseGlobalConfig(string memory json) internal pure returns (GlobalConfig memory gc) {
        // Parse each field explicitly to avoid object-key-order ABI decoding mismatch.
        gc = GlobalConfig({
            mapWidth: vm.parseJsonUint(json, ".globalConfig.mapWidth"),
            mapHeight: vm.parseJsonUint(json, ".globalConfig.mapHeight"),
            mintIntervalBlocks: vm.parseJsonUint(json, ".globalConfig.mintIntervalBlocks"),
            mintAmount: vm.parseJsonUint(json, ".globalConfig.mintAmount"),
            maxMintCount: vm.parseJsonUint(json, ".globalConfig.maxMintCount"),
            stabilizationBlocks: vm.parseJsonUint(json, ".globalConfig.stabilizationBlocks"),
            craftDurationBlocks: vm.parseJsonUint(json, ".globalConfig.craftDurationBlocks"),
            landPrice: vm.parseJsonUint(json, ".globalConfig.landPrice")
        });
    }

    function _parseRecipes(string memory json) internal pure returns (RecipeConfig[] memory recipes) {
        uint256 recipeCount = vm.parseJsonUint(json, ".recipeCount");
        recipes = new RecipeConfig[](recipeCount);

        for (uint256 i = 0; i < recipeCount; i++) {
            string memory base = string.concat(".recipes[", vm.toString(i), "]");
            recipes[i] = RecipeConfig({
                recipeId: vm.parseJsonUint(json, string.concat(base, ".recipeId")),
                resourceTypes: vm.parseJsonUintArray(json, string.concat(base, ".resourceTypes")),
                amounts: vm.parseJsonUintArray(json, string.concat(base, ".amounts")),
                skillId: vm.parseJsonUint(json, string.concat(base, ".skillId")),
                requiredBlocks: vm.parseJsonUint(json, string.concat(base, ".requiredBlocks")),
                outputEqId: vm.parseJsonUint(json, string.concat(base, ".outputEqId"))
            });
        }
    }

    function _parseResourcePoints(string memory json) internal pure returns (ResourcePointConfig[] memory resourcePoints) {
        string[] memory keys = vm.parseJsonKeys(json, ".resourcePoints");
        resourcePoints = new ResourcePointConfig[](keys.length);

        for (uint256 i = 0; i < keys.length; i++) {
            string memory base = string.concat(".resourcePoints[", vm.toString(i), "]");
            resourcePoints[i] = ResourcePointConfig({
                x: vm.parseJsonUint(json, string.concat(base, ".x")),
                y: vm.parseJsonUint(json, string.concat(base, ".y")),
                resourceType: vm.parseJsonUint(json, string.concat(base, ".resourceType")),
                initialStock: vm.parseJsonUint(json, string.concat(base, ".initialStock"))
            });
        }
    }

    function _parseSkills(string memory json) internal pure returns (SkillConfig[] memory skills) {
        string[] memory keys = vm.parseJsonKeys(json, ".skills");
        skills = new SkillConfig[](keys.length);

        for (uint256 i = 0; i < keys.length; i++) {
            string memory base = string.concat(".skills[", vm.toString(i), "]");
            skills[i] = SkillConfig({
                skillId: vm.parseJsonUint(json, string.concat(base, ".skillId")),
                requiredBlocks: vm.parseJsonUint(json, string.concat(base, ".requiredBlocks"))
            });
        }
    }

    function _parseNpcs(string memory json) internal pure returns (NPCConfig[] memory npcs) {
        string[] memory keys = vm.parseJsonKeys(json, ".npcs");
        npcs = new NPCConfig[](keys.length);

        for (uint256 i = 0; i < keys.length; i++) {
            string memory base = string.concat(".npcs[", vm.toString(i), "]");
            npcs[i] = NPCConfig({
                npcId: vm.parseJsonUint(json, string.concat(base, ".npcId")),
                x: vm.parseJsonUint(json, string.concat(base, ".x")),
                y: vm.parseJsonUint(json, string.concat(base, ".y")),
                skillId: vm.parseJsonUint(json, string.concat(base, ".skillId"))
            });
        }
    }

    function _parseEquipments(string memory json) internal pure returns (EquipmentConfig[] memory equipments) {
        string[] memory keys = vm.parseJsonKeys(json, ".equipments");
        equipments = new EquipmentConfig[](keys.length);

        for (uint256 i = 0; i < keys.length; i++) {
            string memory base = string.concat(".equipments[", vm.toString(i), "]");
            equipments[i] = EquipmentConfig({
                equipmentId: vm.parseJsonUint(json, string.concat(base, ".equipmentId")),
                slot: vm.parseJsonUint(json, string.concat(base, ".slot")),
                speedBonus: vm.parseJsonInt(json, string.concat(base, ".speedBonus")),
                attackBonus: vm.parseJsonInt(json, string.concat(base, ".attackBonus")),
                defenseBonus: vm.parseJsonInt(json, string.concat(base, ".defenseBonus")),
                maxHpBonus: vm.parseJsonInt(json, string.concat(base, ".maxHpBonus")),
                rangeBonus: vm.parseJsonInt(json, string.concat(base, ".rangeBonus"))
            });
        }
    }

    function _initGlobalConfig(AgentboxConfig config, GlobalConfig memory gc) internal {
        config.setMapDimensions(gc.mapWidth, gc.mapHeight);
        config.setMintIntervalBlocks(gc.mintIntervalBlocks);
        config.setMintAmount(gc.mintAmount);
        config.setMaxMintCount(gc.maxMintCount);
        config.setStabilizationBlocks(gc.stabilizationBlocks);
        config.setCraftDurationBlocks(gc.craftDurationBlocks);
        config.setLandPrice(gc.landPrice);
    }

    function _initGameContent(
        IAgentboxCore core,
        ResourcePointConfig[] memory resourcePoints,
        SkillConfig[] memory skills,
        NPCConfig[] memory npcs,
        RecipeConfig[] memory recipes,
        EquipmentConfig[] memory equipments
    ) internal {
        for (uint256 i = 0; i < resourcePoints.length; i++) {
            ResourcePointConfig memory p = resourcePoints[i];
            core.setResourcePoint(p.x, p.y, p.resourceType, p.initialStock);
        }

        for (uint256 i = 0; i < skills.length; i++) {
            SkillConfig memory s = skills[i];
            core.setSkillBlocks(s.skillId, s.requiredBlocks);
        }

        for (uint256 i = 0; i < npcs.length; i++) {
            NPCConfig memory n = npcs[i];
            core.setNPC(n.npcId, n.x, n.y, n.skillId);
        }

        for (uint256 i = 0; i < recipes.length; i++) {
            RecipeConfig memory r = recipes[i];
            core.setRecipe(r.recipeId, r.resourceTypes, r.amounts, r.skillId, r.requiredBlocks, r.outputEqId);
        }

        for (uint256 i = 0; i < equipments.length; i++) {
            EquipmentConfig memory e = equipments[i];
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
}
