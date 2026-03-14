// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/proxy/AgentboxDiamond.sol";
import "../src/facets/AdminFacet.sol";

contract UpgradeAdminFacetScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address coreAddress = vm.envAddress("CORE_ADDRESS");
        address adminFacetAddress = vm.envAddress("ADMIN_FACET_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        AgentboxDiamond diamond = AgentboxDiamond(payable(coreAddress));
        AgentboxDiamond.FacetCut[] memory cuts = new AgentboxDiamond.FacetCut[](1);

        bytes4[] memory adminSelectors = new bytes4[](7);
        adminSelectors[0] = AdminFacet.initialize.selector;
        adminSelectors[1] = AdminFacet.withdrawEth.selector;
        adminSelectors[2] = AdminFacet.setResourcePoint.selector;
        adminSelectors[3] = AdminFacet.setSkillBlocks.selector;
        adminSelectors[4] = AdminFacet.setNPC.selector;
        adminSelectors[5] = AdminFacet.setRecipe.selector;
        adminSelectors[6] = AdminFacet.setEquipmentConfig.selector;

        cuts[0] = AgentboxDiamond.FacetCut({
            facetAddress: adminFacetAddress,
            action: AgentboxDiamond.FacetCutAction.Replace,
            functionSelectors: adminSelectors
        });

        diamond.diamondCut(cuts);

        vm.stopBroadcast();

        console.log("=== AdminFacet Upgrade Successful ===");
        console.log("Core (Diamond):", coreAddress);
        console.log("AdminFacet:", adminFacetAddress);
        console.log("====================================");
    }
}
