// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AgentboxRole.sol";
import "../src/AgentboxConfig.sol";
import "../src/AgentboxCore.sol";
import "../src/AgentboxResource.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        vm.startBroadcast(deployerPrivateKey);

        AgentboxRoleWallet walletImpl = new AgentboxRoleWallet();
        AgentboxRole role = new AgentboxRole(address(walletImpl));
        AgentboxConfig config = new AgentboxConfig();
        AgentboxResource resource = new AgentboxResource();

        AgentboxCore coreImpl = new AgentboxCore();

        bytes memory data =
            abi.encodeCall(AgentboxCore.initialize, (address(role), address(config), address(0), address(0), address(resource)));

        ERC1967Proxy proxy = new ERC1967Proxy(address(coreImpl), data);
        AgentboxCore core = AgentboxCore(address(proxy));
        
        resource.setGameCore(address(core));

        vm.stopBroadcast();
    }
}
