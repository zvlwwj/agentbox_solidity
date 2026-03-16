// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/interfaces/IAgentboxCore.sol";

contract SeedRoleScenarioScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address coreAddress = vm.envAddress("CORE_ADDRESS");
        uint256 roleX = vm.envUint("ROLE_X");
        uint256 roleY = vm.envUint("ROLE_Y");

        IAgentboxCore core = IAgentboxCore(coreAddress);

        vm.startBroadcast(deployerPrivateKey);

        core.setResourcePoint(roleX + 1, roleY, 1, 1000);
        core.setResourcePoint(roleX, roleY + 1, 2, 800);
        core.setResourcePoint(roleX, roleY - 1, 3, 900);

        core.setNPC(4, roleX + 2, roleY, 1);
        core.setNPC(5, roleX + 1, roleY + 1, 2);
        core.setNPC(6, roleX + 1, roleY - 1, 3);

        vm.stopBroadcast();

        console.log("=== Role Scenario Seeded ===");
        console.log("Core:", coreAddress);
        console.log("Role center:", roleX, roleY);
        console.log("Wood resource:", roleX + 1, roleY);
        console.log("Wool resource:", roleX, roleY + 1);
        console.log("Stone resource:", roleX, roleY - 1);
        console.log("NPC4 (wood teacher):", roleX + 2, roleY);
        console.log("NPC5 (wool teacher):", roleX + 1, roleY + 1);
        console.log("NPC6 (stone teacher):", roleX + 1, roleY - 1);
        console.log("============================");
    }
}
