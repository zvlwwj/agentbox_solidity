// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AgentboxRandomizer.sol";
import "../src/AgentboxEconomy.sol";

contract DeployVrfDepsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR");
        bytes32 keyHash = vm.envBytes32("VRF_KEY_HASH");
        uint256 subscriptionId = vm.envUint("VRF_SUB_ID");
        address configAddress = vm.envAddress("CONFIG_ADDRESS");
        address coreAddress = vm.envAddress("CORE_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        AgentboxRandomizer randomizer = new AgentboxRandomizer(vrfCoordinator, keyHash, subscriptionId);
        AgentboxEconomy economy = new AgentboxEconomy(configAddress, vrfCoordinator, keyHash, subscriptionId);

        randomizer.setGameCore(coreAddress);
        economy.setGameCore(coreAddress);

        vm.stopBroadcast();

        console.log("=== VRF Dependencies Redeployed ===");
        console.log("Randomizer:", address(randomizer));
        console.log("Economy:", address(economy));
        console.log("Core:", coreAddress);
        console.log("Config:", configAddress);
        console.log("===================================");
    }
}
