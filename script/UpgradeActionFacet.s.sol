// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/proxy/AgentboxDiamond.sol";
import "../src/facets/ActionFacet.sol";

contract UpgradeActionFacetScript is Script {
    function run() external returns (address actionFacetAddress) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address coreAddress = vm.envAddress("CORE_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        ActionFacet actionFacet = new ActionFacet();
        actionFacetAddress = address(actionFacet);

        AgentboxDiamond diamond = AgentboxDiamond(payable(coreAddress));
        AgentboxDiamond.FacetCut[] memory cuts = new AgentboxDiamond.FacetCut[](1);

        bytes4[] memory actionSelectors = new bytes4[](4);
        actionSelectors[0] = ActionFacet.move.selector;
        actionSelectors[1] = ActionFacet.startTeleport.selector;
        actionSelectors[2] = ActionFacet.finishTeleport.selector;
        actionSelectors[3] = ActionFacet.attack.selector;

        cuts[0] = AgentboxDiamond.FacetCut({
            facetAddress: actionFacetAddress,
            action: AgentboxDiamond.FacetCutAction.Replace,
            functionSelectors: actionSelectors
        });

        diamond.diamondCut(cuts);

        vm.stopBroadcast();

        console.log("=== ActionFacet Upgrade Successful ===");
        console.log("Core (Diamond):", coreAddress);
        console.log("ActionFacet:", actionFacetAddress);
        console.log("=====================================");
    }
}
