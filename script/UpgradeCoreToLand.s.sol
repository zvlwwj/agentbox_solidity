// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/proxy/AgentboxDiamond.sol";
import "../src/interfaces/IAgentboxCore.sol";
import "../src/AgentboxLand.sol";
import "../src/facets/AdminFacet.sol";
import "../src/facets/MapFacet.sol";
import "../src/facets/RoleFacet.sol";
import "../src/facets/ReadFacet.sol";

contract UpgradeCoreToLandScript is Script {
    bytes4 private constant OLD_ADMIN_INITIALIZE_SELECTOR =
        bytes4(keccak256("initialize(address,address,address,address,address)"));
    bytes4 private constant OLD_SET_LAND_CONTRACT_SELECTOR =
        bytes4(keccak256("setLandContract(uint256,uint256,address)"));

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address coreAddress = vm.envAddress("CORE_ADDRESS");
        address roleAddress = vm.envAddress("ROLE_ADDRESS");
        address configAddress = vm.envAddress("CONFIG_ADDRESS");
        address economyAddress = vm.envAddress("ECONOMY_ADDRESS");
        address randomizerAddress = vm.envAddress("RANDOMIZER_ADDRESS");
        address resourceAddress = vm.envAddress("RESOURCE_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        AgentboxLand land = new AgentboxLand();
        AdminFacet adminFacet = new AdminFacet();
        MapFacet mapFacet = new MapFacet();
        RoleFacet roleFacet = new RoleFacet();
        ReadFacet readFacet = new ReadFacet();

        AgentboxDiamond diamond = AgentboxDiamond(payable(coreAddress));
        AgentboxDiamond.FacetCut[] memory cuts = new AgentboxDiamond.FacetCut[](6);

        bytes4[] memory adminReplaceSelectors = new bytes4[](7);
        adminReplaceSelectors[0] = AdminFacet.initialize.selector;
        adminReplaceSelectors[1] = AdminFacet.withdrawEth.selector;
        adminReplaceSelectors[2] = AdminFacet.setResourcePoint.selector;
        adminReplaceSelectors[3] = AdminFacet.setSkillBlocks.selector;
        adminReplaceSelectors[4] = AdminFacet.setNPC.selector;
        adminReplaceSelectors[5] = AdminFacet.setRecipe.selector;
        adminReplaceSelectors[6] = AdminFacet.setEquipmentConfig.selector;
        cuts[0] = AgentboxDiamond.FacetCut({
            facetAddress: address(adminFacet),
            action: AgentboxDiamond.FacetCutAction.Replace,
            functionSelectors: adminReplaceSelectors
        });

        bytes4[] memory adminRemoveSelectors = new bytes4[](1);
        adminRemoveSelectors[0] = OLD_ADMIN_INITIALIZE_SELECTOR;
        cuts[1] = AgentboxDiamond.FacetCut({
            facetAddress: address(0),
            action: AgentboxDiamond.FacetCutAction.Remove,
            functionSelectors: adminRemoveSelectors
        });

        bytes4[] memory mapReplaceSelectors = new bytes4[](4);
        mapReplaceSelectors[0] = MapFacet.getEntityPosition.selector;
        mapReplaceSelectors[1] = MapFacet.buyLand.selector;
        mapReplaceSelectors[2] = MapFacet.sellLand.selector;
        mapReplaceSelectors[3] = MapFacet.setLandContract.selector;
        cuts[2] = AgentboxDiamond.FacetCut({
            facetAddress: address(mapFacet),
            action: AgentboxDiamond.FacetCutAction.Replace,
            functionSelectors: mapReplaceSelectors
        });

        bytes4[] memory mapRemoveSelectors = new bytes4[](1);
        mapRemoveSelectors[0] = OLD_SET_LAND_CONTRACT_SELECTOR;
        cuts[3] = AgentboxDiamond.FacetCut({
            facetAddress: address(0),
            action: AgentboxDiamond.FacetCutAction.Remove,
            functionSelectors: mapRemoveSelectors
        });

        bytes4[] memory roleReplaceSelectors = new bytes4[](4);
        roleReplaceSelectors[0] = bytes4(keccak256("createCharacter()"));
        roleReplaceSelectors[1] = bytes4(keccak256("createCharacter(string,uint8)"));
        roleReplaceSelectors[2] = RoleFacet.processSpawn.selector;
        roleReplaceSelectors[3] = RoleFacet.processRespawn.selector;
        cuts[4] = AgentboxDiamond.FacetCut({
            facetAddress: address(roleFacet),
            action: AgentboxDiamond.FacetCutAction.Replace,
            functionSelectors: roleReplaceSelectors
        });

        bytes4[] memory readReplaceSelectors = new bytes4[](19);
        readReplaceSelectors[0] = ReadFacet.getCoreContracts.selector;
        readReplaceSelectors[1] = ReadFacet.getGlobalConfig.selector;
        readReplaceSelectors[2] = ReadFacet.getRoleIdentity.selector;
        readReplaceSelectors[3] = ReadFacet.getRoleSnapshot.selector;
        readReplaceSelectors[4] = ReadFacet.getRoleProfile.selector;
        readReplaceSelectors[5] = ReadFacet.getRoleWalletByNickname.selector;
        readReplaceSelectors[6] = ReadFacet.getRoleActionSnapshot.selector;
        readReplaceSelectors[7] = ReadFacet.getRoleSkill.selector;
        readReplaceSelectors[8] = ReadFacet.getRoleSkills.selector;
        readReplaceSelectors[9] = ReadFacet.getEquipped.selector;
        readReplaceSelectors[10] = ReadFacet.getEquippedBatch.selector;
        readReplaceSelectors[11] = ReadFacet.getLandSnapshot.selector;
        readReplaceSelectors[12] = ReadFacet.getLandSnapshotById.selector;
        readReplaceSelectors[13] = ReadFacet.getNpcSnapshot.selector;
        readReplaceSelectors[14] = ReadFacet.getRecipeSnapshot.selector;
        readReplaceSelectors[15] = ReadFacet.getEquipmentSnapshot.selector;
        readReplaceSelectors[16] = ReadFacet.getSkillRequiredBlocks.selector;
        readReplaceSelectors[17] = ReadFacet.getEconomyBalances.selector;
        readReplaceSelectors[18] = ReadFacet.canFinishCurrentAction.selector;
        cuts[5] = AgentboxDiamond.FacetCut({
            facetAddress: address(readFacet),
            action: AgentboxDiamond.FacetCutAction.Replace,
            functionSelectors: readReplaceSelectors
        });

        diamond.diamondCut(cuts);

        IAgentboxCore(coreAddress).initialize(
            roleAddress,
            configAddress,
            economyAddress,
            randomizerAddress,
            resourceAddress,
            address(land)
        );
        land.setGameCore(coreAddress);

        vm.stopBroadcast();

        console.log("=== Core Upgrade Successful ===");
        console.log("Core (Diamond):", coreAddress);
        console.log("Land (ERC721):", address(land));
        console.log("AdminFacet:", address(adminFacet));
        console.log("MapFacet:", address(mapFacet));
        console.log("RoleFacet:", address(roleFacet));
        console.log("ReadFacet:", address(readFacet));
        console.log("===============================");
    }
}
