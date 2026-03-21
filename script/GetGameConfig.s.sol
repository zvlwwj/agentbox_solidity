// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "../src/AgentboxConfig.sol";

contract GetGameConfigScript is Script {
    using stdJson for string;

    function run() external view {
        address configAddress = _resolveConfigAddress();
        AgentboxConfig config = AgentboxConfig(configAddress);

        console.log("=== Game Config ===");
        console.log("Config:", configAddress);
        console.log("mapWidth:", config.mapWidth());
        console.log("mapHeight:", config.mapHeight());
        console.log("mintIntervalBlocks:", config.mintIntervalBlocks());
        console.log("mintAmount:", config.mintAmount());
        console.log("maxMintCount:", config.maxMintCount());
        console.log("stabilizationBlocks:", config.stabilizationBlocks());
        console.log("craftDurationBlocks:", config.craftDurationBlocks());
        console.log("landPrice:", config.landPrice());
        console.log("===================");
    }

    function _resolveConfigAddress() internal view returns (address configAddress) {
        configAddress = vm.envOr("CONFIG_ADDRESS", address(0));
        if (configAddress != address(0)) {
            return configAddress;
        }

        string memory deploymentsJson = vm.readFile("deployments.json");
        configAddress = deploymentsJson.readAddress(".contracts.Config");
        require(configAddress != address(0), "CONFIG_ADDRESS not found");
    }
}
