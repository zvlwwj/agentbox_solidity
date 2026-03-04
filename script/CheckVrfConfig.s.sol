// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AgentboxRandomizer.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFSubscriptionV2Plus.sol";

contract CheckVrfConfigScript is Script {
    function run() external view {
        address randomizerAddr = vm.envAddress("RANDOMIZER_ADDRESS");
        address expectedCore = vm.envAddress("CORE_ADDRESS");
        address expectedCoordinator = vm.envAddress("VRF_COORDINATOR");
        bytes32 expectedKeyHash = vm.envBytes32("VRF_KEY_HASH");
        uint256 expectedSubId = vm.envUint("VRF_SUB_ID");
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));

        AgentboxRandomizer randomizer = AgentboxRandomizer(randomizerAddr);
        address onchainCore = randomizer.gameCore();
        address onchainCoordinator = address(randomizer.s_vrfCoordinator());
        bytes32 onchainKeyHash = randomizer.s_keyHash();
        uint256 onchainSubId = randomizer.s_subscriptionId();
        address onchainOwner = randomizer.owner();

        IVRFSubscriptionV2Plus coordinator = IVRFSubscriptionV2Plus(expectedCoordinator);
        (uint96 linkBalance, uint96 nativeBalance, uint64 reqCount, address subOwner, address[] memory consumers) =
            coordinator.getSubscription(expectedSubId);

        bool isConsumer = _contains(consumers, randomizerAddr);

        console.log("=== VRF Config Self Check ===");
        console.log("chainId:", block.chainid);
        console.log("randomizer:", randomizerAddr);
        console.log("deployer:", deployer);
        console.log("");

        _checkAddress("core", expectedCore, onchainCore);
        _checkAddress("coordinator", expectedCoordinator, onchainCoordinator);
        _checkBytes32("keyHash", expectedKeyHash, onchainKeyHash);
        _checkUint("subId", expectedSubId, onchainSubId);
        _checkAddress("randomizerOwner", deployer, onchainOwner);

        console.log("");
        console.log("subscriptionOwner:", subOwner);
        console.log("subscriptionLinkBalance:", uint256(linkBalance));
        console.log("subscriptionNativeBalance:", uint256(nativeBalance));
        console.log("subscriptionReqCount:", uint256(reqCount));
        console.log("randomizerIsConsumer:", isConsumer);
        console.log("=============================");
    }

    function _contains(address[] memory arr, address target) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == target) return true;
        }
        return false;
    }

    function _checkAddress(string memory label, address expected, address actual) internal pure {
        console.log(label);
        console.log("  expected:", expected);
        console.log("  actual:", actual);
        console.log("  match:", expected == actual);
    }

    function _checkBytes32(string memory label, bytes32 expected, bytes32 actual) internal pure {
        console.log(label);
        console.logBytes32(expected);
        console.logBytes32(actual);
        console.log("  match:", expected == actual);
    }

    function _checkUint(string memory label, uint256 expected, uint256 actual) internal pure {
        console.log(label);
        console.log("  expected:", expected);
        console.log("  actual:", actual);
        console.log("  match:", expected == actual);
    }
}
