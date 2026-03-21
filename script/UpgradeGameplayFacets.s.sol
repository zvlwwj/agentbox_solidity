// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/proxy/AgentboxDiamond.sol";
import "../src/facets/ActionFacet.sol";
import "../src/facets/RoleFacet.sol";
import "../src/facets/ReadFacet.sol";

contract UpgradeGameplayFacetsScript is Script {
    function run() external returns (address actionFacetAddress, address roleFacetAddress, address readFacetAddress) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address coreAddress = vm.envAddress("CORE_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        ActionFacet actionFacet = new ActionFacet();
        RoleFacet roleFacet = new RoleFacet();
        ReadFacet readFacet = new ReadFacet();

        actionFacetAddress = address(actionFacet);
        roleFacetAddress = address(roleFacet);
        readFacetAddress = address(readFacet);

        AgentboxDiamond diamond = AgentboxDiamond(payable(coreAddress));
        AgentboxDiamond.FacetCut[] memory cuts = new AgentboxDiamond.FacetCut[](3);

        bytes4[] memory actionSelectors = new bytes4[](4);
        actionSelectors[0] = ActionFacet.moveTo.selector;
        actionSelectors[1] = ActionFacet.startTeleport.selector;
        actionSelectors[2] = ActionFacet.finishTeleport.selector;
        actionSelectors[3] = ActionFacet.attack.selector;
        cuts[0] = AgentboxDiamond.FacetCut({
            facetAddress: actionFacetAddress,
            action: AgentboxDiamond.FacetCutAction.Replace,
            functionSelectors: actionSelectors
        });

        bytes4[] memory roleSelectors = new bytes4[](4);
        roleSelectors[0] = bytes4(keccak256("createCharacter()"));
        roleSelectors[1] = bytes4(keccak256("createCharacter(string,uint8)"));
        roleSelectors[2] = RoleFacet.processSpawn.selector;
        roleSelectors[3] = RoleFacet.processRespawn.selector;
        cuts[1] = AgentboxDiamond.FacetCut({
            facetAddress: roleFacetAddress,
            action: AgentboxDiamond.FacetCutAction.Replace,
            functionSelectors: roleSelectors
        });

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
        cuts[2] = AgentboxDiamond.FacetCut({
            facetAddress: readFacetAddress,
            action: AgentboxDiamond.FacetCutAction.Replace,
            functionSelectors: readSelectors
        });

        diamond.diamondCut(cuts);

        vm.stopBroadcast();

        console.log("=== Gameplay Facets Upgrade Successful ===");
        console.log("Core (Diamond):", coreAddress);
        console.log("ActionFacet:", actionFacetAddress);
        console.log("RoleFacet:", roleFacetAddress);
        console.log("ReadFacet:", readFacetAddress);
        console.log("=========================================");
    }
}
