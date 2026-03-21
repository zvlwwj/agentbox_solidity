// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AgentboxRoleWallet.sol";
import "../src/AgentboxRole.sol";
import "../src/AgentboxConfig.sol";
import "../src/AgentboxResource.sol";
import "../src/AgentboxLand.sol";
import "../src/AgentboxEconomy.sol";
import "../src/AgentboxRandomizer.sol";
import "../src/proxy/AgentboxDiamond.sol";
import "../src/facets/AdminFacet.sol";
import "../src/facets/ActionFacet.sol";
import "../src/facets/GatherCraftFacet.sol";
import "../src/facets/LearnFacet.sol";
import "../src/facets/MapFacet.sol";
import "../src/facets/ReadFacet.sol";
import "../src/facets/RoleFacet.sol";
import "../src/facets/SocialFacet.sol";
import "../src/facets/DiamondLoupeFacet.sol";
import "../src/interfaces/IAgentboxCore.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR");
        bytes32 keyHash = vm.envBytes32("VRF_KEY_HASH");
        uint256 subscriptionId = vm.envUint("VRF_SUB_ID");

        vm.startBroadcast(deployerPrivateKey);

        AgentboxConfig config = new AgentboxConfig();
        AgentboxRoleWallet walletImpl = new AgentboxRoleWallet();
        AgentboxRole role = new AgentboxRole(address(walletImpl));
        AgentboxResource resource = new AgentboxResource();
        AgentboxLand land = new AgentboxLand();
        AgentboxRandomizer randomizer = new AgentboxRandomizer(vrfCoordinator, keyHash, subscriptionId);
        AgentboxEconomy economy = new AgentboxEconomy(address(config), vrfCoordinator, keyHash, subscriptionId);

        // Deploy Diamond
        AgentboxDiamond diamond = new AgentboxDiamond();
        
        // Deploy Facets
        AdminFacet adminFacet = new AdminFacet();
        ActionFacet actionFacet = new ActionFacet();
        GatherCraftFacet gatherCraftFacet = new GatherCraftFacet();
        LearnFacet learnFacet = new LearnFacet();
        MapFacet mapFacet = new MapFacet();
        ReadFacet readFacet = new ReadFacet();
        RoleFacet roleFacet = new RoleFacet();
        SocialFacet socialFacet = new SocialFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();

        // Build Diamond Cut
        AgentboxDiamond.FacetCut[] memory cuts = new AgentboxDiamond.FacetCut[](9);
        
        bytes4[] memory adminSelectors = new bytes4[](7);
        adminSelectors[0] = AdminFacet.initialize.selector;
        adminSelectors[1] = AdminFacet.withdrawEth.selector;
        adminSelectors[2] = AdminFacet.setResourcePoint.selector;
        adminSelectors[3] = AdminFacet.setSkillBlocks.selector;
        adminSelectors[4] = AdminFacet.setNPC.selector;
        adminSelectors[5] = AdminFacet.setRecipe.selector;
        adminSelectors[6] = AdminFacet.setEquipmentConfig.selector;
        cuts[0] = AgentboxDiamond.FacetCut({facetAddress: address(adminFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: adminSelectors});

        bytes4[] memory actionSelectors = new bytes4[](4);
        actionSelectors[0] = ActionFacet.moveTo.selector;
        actionSelectors[1] = ActionFacet.startTeleport.selector;
        actionSelectors[2] = ActionFacet.finishTeleport.selector;
        actionSelectors[3] = ActionFacet.attack.selector;
        cuts[1] = AgentboxDiamond.FacetCut({facetAddress: address(actionFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: actionSelectors});

        bytes4[] memory gatherCraftSelectors = new bytes4[](7);
        gatherCraftSelectors[0] = GatherCraftFacet.gather.selector;
        gatherCraftSelectors[1] = GatherCraftFacet.startGather.selector;
        gatherCraftSelectors[2] = GatherCraftFacet.finishGather.selector;
        gatherCraftSelectors[3] = GatherCraftFacet.startCrafting.selector;
        gatherCraftSelectors[4] = GatherCraftFacet.finishCrafting.selector;
        gatherCraftSelectors[5] = GatherCraftFacet.equip.selector;
        gatherCraftSelectors[6] = GatherCraftFacet.unequip.selector;
        cuts[2] = AgentboxDiamond.FacetCut({facetAddress: address(gatherCraftFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: gatherCraftSelectors});

        bytes4[] memory learnSelectors = new bytes4[](7);
        learnSelectors[0] = LearnFacet.startLearning.selector;
        learnSelectors[1] = LearnFacet.requestLearningFromPlayer.selector;
        learnSelectors[2] = LearnFacet.acceptTeaching.selector;
        learnSelectors[3] = LearnFacet.cancelLearning.selector;
        learnSelectors[4] = LearnFacet.cancelTeaching.selector;
        learnSelectors[5] = LearnFacet.finishLearning.selector;
        learnSelectors[6] = LearnFacet.processNPCRefresh.selector;
        cuts[3] = AgentboxDiamond.FacetCut({facetAddress: address(learnFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: learnSelectors});

        bytes4[] memory mapSelectors = new bytes4[](4);
        mapSelectors[0] = MapFacet.getEntityPosition.selector;
        mapSelectors[1] = MapFacet.buyLand.selector;
        mapSelectors[2] = MapFacet.sellLand.selector;
        mapSelectors[3] = MapFacet.setLandContract.selector;
        cuts[4] = AgentboxDiamond.FacetCut({facetAddress: address(mapFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: mapSelectors});

        bytes4[] memory readSelectors = new bytes4[](19);
        readSelectors[0] = ReadFacet.getCoreContracts.selector;
        readSelectors[1] = ReadFacet.getGlobalConfig.selector;
        readSelectors[2] = ReadFacet.getRoleIdentity.selector;
        readSelectors[3] = ReadFacet.getRoleSnapshot.selector;
        readSelectors[4] = ReadFacet.getRoleProfile.selector;
        readSelectors[5] = ReadFacet.getRoleWalletByNickname.selector;
        readSelectors[6] = ReadFacet.getRoleActionSnapshot.selector;
        readSelectors[7] = ReadFacet.getRoleSkill.selector;
        readSelectors[8] = ReadFacet.getRoleSkills.selector;
        readSelectors[9] = ReadFacet.getEquipped.selector;
        readSelectors[10] = ReadFacet.getEquippedBatch.selector;
        readSelectors[11] = ReadFacet.getLandSnapshot.selector;
        readSelectors[12] = ReadFacet.getLandSnapshotById.selector;
        readSelectors[13] = ReadFacet.getNpcSnapshot.selector;
        readSelectors[14] = ReadFacet.getRecipeSnapshot.selector;
        readSelectors[15] = ReadFacet.getEquipmentSnapshot.selector;
        readSelectors[16] = ReadFacet.getSkillRequiredBlocks.selector;
        readSelectors[17] = ReadFacet.getEconomyBalances.selector;
        readSelectors[18] = ReadFacet.canFinishCurrentAction.selector;
        cuts[5] = AgentboxDiamond.FacetCut({facetAddress: address(readFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: readSelectors});

        bytes4[] memory roleSelectors = new bytes4[](4);
        roleSelectors[0] = bytes4(keccak256("createCharacter()"));
        roleSelectors[1] = bytes4(keccak256("createCharacter(string,uint8)"));
        roleSelectors[2] = RoleFacet.processSpawn.selector;
        roleSelectors[3] = RoleFacet.processRespawn.selector;
        cuts[6] = AgentboxDiamond.FacetCut({facetAddress: address(roleFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: roleSelectors});

        bytes4[] memory socialSelectors = new bytes4[](2);
        socialSelectors[0] = SocialFacet.sendMessage.selector;
        socialSelectors[1] = SocialFacet.sendGlobalMessage.selector;
        cuts[7] = AgentboxDiamond.FacetCut({facetAddress: address(socialFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: socialSelectors});

        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        cuts[8] = AgentboxDiamond.FacetCut({facetAddress: address(diamondLoupeFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: loupeSelectors});

        // Execute Cut
        diamond.diamondCut(cuts);

        // Initialize Core via Diamond
        IAgentboxCore core = IAgentboxCore(address(diamond));
        core.initialize(address(role), address(config), address(economy), address(randomizer), address(resource), address(land));
        
        // Set GameCore references
        resource.setGameCore(address(core));
        land.setGameCore(address(core));
        randomizer.setGameCore(address(core));
        economy.setGameCore(address(core));
        role.setGameCore(address(core));

        vm.stopBroadcast();
        
        console.log("=== Deployment Successful ===");
        console.log("Config:", address(config));
        console.log("Role (NFT):", address(role));
        console.log("Land (ERC721):", address(land));
        console.log("Resource (ERC1155):", address(resource));
        console.log("Randomizer:", address(randomizer));
        console.log("Economy (ERC20):", address(economy));
        console.log("Core (Diamond):", address(core));
        console.log("============================");
    }
}
