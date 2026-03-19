// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/proxy/AgentboxDiamond.sol";
import "../src/facets/LearnFacet.sol";

contract UpgradeLearnFacetScript is Script {
    function run() external returns (address learnFacetAddress) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address coreAddress = vm.envAddress("CORE_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        LearnFacet learnFacet = new LearnFacet();
        learnFacetAddress = address(learnFacet);

        AgentboxDiamond diamond = AgentboxDiamond(payable(coreAddress));
        AgentboxDiamond.FacetCut[] memory cuts = new AgentboxDiamond.FacetCut[](1);

        bytes4[] memory learnSelectors = new bytes4[](7);
        learnSelectors[0] = LearnFacet.startLearning.selector;
        learnSelectors[1] = LearnFacet.requestLearningFromPlayer.selector;
        learnSelectors[2] = LearnFacet.acceptTeaching.selector;
        learnSelectors[3] = LearnFacet.cancelLearning.selector;
        learnSelectors[4] = LearnFacet.cancelTeaching.selector;
        learnSelectors[5] = LearnFacet.finishLearning.selector;
        learnSelectors[6] = LearnFacet.processNPCRefresh.selector;

        cuts[0] = AgentboxDiamond.FacetCut({
            facetAddress: learnFacetAddress,
            action: AgentboxDiamond.FacetCutAction.Replace,
            functionSelectors: learnSelectors
        });

        diamond.diamondCut(cuts);

        vm.stopBroadcast();

        console.log("=== LearnFacet Upgrade Successful ===");
        console.log("Core (Diamond):", coreAddress);
        console.log("LearnFacet:", learnFacetAddress);
        console.log("====================================");
    }
}
