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
        uint256 stabilizationBlocks;
        uint256 craftDurationBlocks;
        uint256 halvingIntervalBlocks;
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
        GlobalConfig memory globalConfig = abi.decode(vm.parseJson(json, ".globalConfig"), (GlobalConfig));
        ResourcePointConfig[] memory resourcePoints =
            abi.decode(vm.parseJson(json, ".resourcePoints"), (ResourcePointConfig[]));
        SkillConfig[] memory skills = abi.decode(vm.parseJson(json, ".skills"), (SkillConfig[]));
        NPCConfig[] memory npcs = abi.decode(vm.parseJson(json, ".npcs"), (NPCConfig[]));
        RecipeConfig[] memory recipes = _parseRecipes(json);
        EquipmentConfig[] memory equipments = abi.decode(vm.parseJson(json, ".equipments"), (EquipmentConfig[]));

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

    function _initGlobalConfig(AgentboxConfig config, GlobalConfig memory gc) internal {
        config.setMapDimensions(gc.mapWidth, gc.mapHeight);
        config.setMintIntervalBlocks(gc.mintIntervalBlocks);
        config.setMintAmount(gc.mintAmount);
        config.setStabilizationBlocks(gc.stabilizationBlocks);
        config.setCraftDurationBlocks(gc.craftDurationBlocks);
        config.setHalvingIntervalBlocks(gc.halvingIntervalBlocks);
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
