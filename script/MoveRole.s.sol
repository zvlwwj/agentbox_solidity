// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/interfaces/IAgentboxCore.sol";

contract MoveRoleScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address coreAddress = vm.envAddress("CORE_ADDRESS");
        address roleWallet = vm.envAddress("ROLE_WALLET");
        uint256 targetX = vm.envUint("MOVE_TARGET_X");
        uint256 targetY = vm.envUint("MOVE_TARGET_Y");

        vm.startBroadcast(deployerPrivateKey);
        IAgentboxCore(coreAddress).moveTo(roleWallet, targetX, targetY);
        vm.stopBroadcast();
    }
}
