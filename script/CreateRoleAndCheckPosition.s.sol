// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "../src/AgentboxRole.sol";
import "../src/interfaces/IAgentboxCore.sol";

contract CreateRoleAndCheckPositionScript is Script {
    using stdJson for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address coreAddress = _resolveAddress("CORE_ADDRESS", ".contracts.Core_Diamond");
        address roleAddress = _resolveAddress("ROLE_ADDRESS", ".contracts.Role_NFT");

        AgentboxRole role = AgentboxRole(roleAddress);
        IAgentboxCore core = IAgentboxCore(coreAddress);

        vm.startBroadcast(deployerPrivateKey);
        uint256 roleId = role.totalMinted();
        core.createCharacter{value: 0.01 ether}();
        address roleWallet = role.wallets(roleId);
        vm.stopBroadcast();

        (bool isValid, uint256 x, uint256 y) = core.getEntityPosition(roleWallet);

        console.log("=== Role Created ===");
        console.log("Role contract:", roleAddress);
        console.log("Core contract:", coreAddress);
        console.log("Role ID:", roleId);
        console.log("Role wallet:", roleWallet);
        console.log("Position valid:", isValid);
        console.log("X:", x);
        console.log("Y:", y);
        if (!isValid) {
            console.log("VRF callback may still be pending. Re-run query script with ROLE_ID.");
        }
        console.log("====================");
    }

    function _resolveAddress(string memory envKey, string memory jsonPath) internal view returns (address addr) {
        addr = vm.envOr(envKey, address(0));
        if (addr != address(0)) return addr;

        string memory deploymentsJson = vm.readFile("deployments.json");
        addr = deploymentsJson.readAddress(jsonPath);
        require(addr != address(0), "address not found");
    }
}

contract QueryRolePositionScript is Script {
    using stdJson for string;

    function run() external view {
        uint256 roleId = vm.envUint("ROLE_ID");
        address roleAddress = _resolveAddress("ROLE_ADDRESS", ".contracts.Role_NFT");
        address coreAddress = _resolveAddress("CORE_ADDRESS", ".contracts.Core_Diamond");

        AgentboxRole role = AgentboxRole(roleAddress);
        IAgentboxCore core = IAgentboxCore(coreAddress);

        address roleWallet = role.wallets(roleId);
        (bool isValid, uint256 x, uint256 y) = core.getEntityPosition(roleWallet);

        console.log("=== Role Position ===");
        console.log("Role ID:", roleId);
        console.log("Role wallet:", roleWallet);
        console.log("Position valid:", isValid);
        console.log("X:", x);
        console.log("Y:", y);
        console.log("=====================");
    }

    function _resolveAddress(string memory envKey, string memory jsonPath) internal view returns (address addr) {
        addr = vm.envOr(envKey, address(0));
        if (addr != address(0)) return addr;

        string memory deploymentsJson = vm.readFile("deployments.json");
        addr = deploymentsJson.readAddress(jsonPath);
        require(addr != address(0), "address not found");
    }
}
