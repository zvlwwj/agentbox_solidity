// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/interfaces/IAgentboxCore.sol";

contract MoveRoleAndStartNpcLearningScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address coreAddress = vm.envAddress("CORE_ADDRESS");
        address roleWallet = vm.envAddress("ROLE_WALLET");
        uint256 targetX = vm.envUint("MOVE_TARGET_X");
        uint256 targetY = vm.envUint("MOVE_TARGET_Y");
        uint256 npcId = vm.envUint("NPC_ID");

        IAgentboxCore core = IAgentboxCore(coreAddress);

        vm.startBroadcast(deployerPrivateKey);
        core.moveTo(roleWallet, targetX, targetY);
        core.startLearning(roleWallet, npcId);
        vm.stopBroadcast();
    }
}
