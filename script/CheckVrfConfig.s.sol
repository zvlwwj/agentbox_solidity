// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AgentboxRandomizer.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFSubscriptionV2Plus.sol";

contract CheckVrfConfigScript is Script {
    struct OnchainConfig {
        address core;
        address coordinator;
        bytes32 keyHash;
        uint256 subId;
        address owner;
    }

    struct SubscriptionDetails {
        uint96 linkBalance;
        uint96 nativeBalance;
        uint64 reqCount;
        address owner;
        bool isConsumer;
    }

    function run() external view {
        address randomizerAddr = vm.envAddress("RANDOMIZER_ADDRESS");
        address expectedCore = vm.envAddress("CORE_ADDRESS");
        address expectedCoordinator = vm.envAddress("VRF_COORDINATOR");
        bytes32 expectedKeyHash = vm.envBytes32("VRF_KEY_HASH");
        uint256 expectedSubId = vm.envUint("VRF_SUB_ID");
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));

        OnchainConfig memory onchain = _loadOnchainConfig(randomizerAddr);
        SubscriptionDetails memory subscription = _loadSubscriptionDetails(expectedCoordinator, expectedSubId, randomizerAddr);

        console.log("=== VRF Config Self Check ===");
        console.log("chainId:", block.chainid);
        console.log("randomizer:", randomizerAddr);
        console.log("deployer:", deployer);
        console.log("");

        _checkAddress("core", expectedCore, onchain.core);
        _checkAddress("coordinator", expectedCoordinator, onchain.coordinator);
        _checkBytes32("keyHash", expectedKeyHash, onchain.keyHash);
        _checkUint("subId", expectedSubId, onchain.subId);
        _checkAddress("randomizerOwner", deployer, onchain.owner);

        console.log("");
        console.log("subscriptionOwner:", subscription.owner);
        console.log("subscriptionLinkBalance:", uint256(subscription.linkBalance));
        console.log("subscriptionNativeBalance:", uint256(subscription.nativeBalance));
        console.log("subscriptionReqCount:", uint256(subscription.reqCount));
        console.log("randomizerIsConsumer:", subscription.isConsumer);
        console.log("=============================");
    }

    function _loadOnchainConfig(address randomizerAddr) internal view returns (OnchainConfig memory config) {
        AgentboxRandomizer randomizer = AgentboxRandomizer(randomizerAddr);
        config = OnchainConfig({
            core: randomizer.gameCore(),
            coordinator: address(randomizer.s_vrfCoordinator()),
            keyHash: randomizer.s_keyHash(),
            subId: randomizer.s_subscriptionId(),
            owner: randomizer.owner()
        });
    }

    function _loadSubscriptionDetails(
        address coordinatorAddr,
        uint256 subId,
        address randomizerAddr
    ) internal view returns (SubscriptionDetails memory details) {
        IVRFSubscriptionV2Plus coordinator = IVRFSubscriptionV2Plus(coordinatorAddr);
        (uint96 linkBalance, uint96 nativeBalance, uint64 reqCount, address owner, address[] memory consumers) =
            coordinator.getSubscription(subId);
        details = SubscriptionDetails({
            linkBalance: linkBalance,
            nativeBalance: nativeBalance,
            reqCount: reqCount,
            owner: owner,
            isConsumer: _contains(consumers, randomizerAddr)
        });
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
