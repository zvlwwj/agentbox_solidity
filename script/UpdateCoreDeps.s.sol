// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/interfaces/IAgentboxCore.sol";

contract UpdateCoreDepsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address coreAddress = vm.envAddress("CORE_ADDRESS");
        address roleAddress = vm.envAddress("ROLE_ADDRESS");
        address configAddress = vm.envAddress("CONFIG_ADDRESS");
        address economyAddress = vm.envAddress("ECONOMY_ADDRESS");
        address randomizerAddress = vm.envAddress("RANDOMIZER_ADDRESS");
        address resourceAddress = vm.envAddress("RESOURCE_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        IAgentboxCore(coreAddress).initialize(
            roleAddress,
            configAddress,
            economyAddress,
            randomizerAddress,
            resourceAddress
        );
        vm.stopBroadcast();

        console.log("=== Core Dependencies Updated ===");
        console.log("Core:", coreAddress);
        console.log("Role:", roleAddress);
        console.log("Config:", configAddress);
        console.log("Economy:", economyAddress);
        console.log("Randomizer:", randomizerAddress);
        console.log("Resource:", resourceAddress);
        console.log("=================================");
    }
}
