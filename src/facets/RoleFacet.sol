// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Errors.sol";

import "./AgentboxBase.sol";
import "../AgentboxConfig.sol";

contract RoleFacet is AgentboxBase {
    function registerCharacter(uint256 roleId) external payable {
        if (!(msg.value == 0.01 ether)) revert Requires001EthToRegister();

        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxRole roleToken = AgentboxRole(state.roleContract);
        if (!(roleToken.ownerOf(roleId) == msg.sender)) revert NotOwner();

        address roleWallet = roleToken.wallets(roleId);
        if (!(roleWallet != address(0))) revert WalletNotDeployed();

        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        if (!(role.attributes.maxHp == 0 && role.state != AgentboxStorage.RoleState.PendingSpawn)) revert AlreadyRegisteredOrPending();

        role.state = AgentboxStorage.RoleState.PendingSpawn;

        if (state.randomizerContract != address(0)) {
            (bool success,) = state.randomizerContract.call(abi.encodeWithSignature("requestSpawn(uint256)", roleId));
            if (!(success)) revert RandomizerRequestFailed();
        } else {
            // Fallback for testing without randomizer (though not recommended for prod)
            _finalizeSpawn(roleId, uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))));
        }
    }

    function processSpawn(uint256 roleId, uint256 randomWord) external onlyRandomizer {
        _finalizeSpawn(roleId, randomWord);
    }

    function _finalizeSpawn(uint256 roleId, uint256 randomWord) internal {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxRole roleToken = AgentboxRole(state.roleContract);
        address roleWallet = roleToken.wallets(roleId);

        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        if (!(role.state == AgentboxStorage.RoleState.PendingSpawn)) revert NotPendingSpawn();

        role.attributes.maxHp = 100;
        role.attributes.hp = 100;
        role.attributes.attack = 10;
        role.attributes.defense = 0;
        role.attributes.speed = 3;
        role.attributes.range = 1;

        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 mapWidth = config.mapWidth();
        uint256 mapHeight = config.mapHeight();

        uint256 startX = randomWord % mapWidth;
        uint256 startY = (randomWord / mapWidth) % mapHeight;

        role.position.x = uint32(startX);
        role.position.y = uint32(startY);
        role.state = AgentboxStorage.RoleState.Idle;

        address owner = roleToken.ownerOf(roleId);

        if (state.totalRegistered < 2000) {
            uint256 landId = startY * mapWidth + startX;
            if (state.landOwners[landId] == address(0)) {
                state.landOwners[landId] = owner;
                emit LandBought(landId, owner);
            }
        }

        state.totalRegistered++;

        emit CharacterRegistered(roleId, roleWallet);
    }

    function processRespawn(uint256 roleId, uint256 randomWord) external onlyRandomizer {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxRole roleToken = AgentboxRole(state.roleContract);
        address roleWallet = roleToken.wallets(roleId);

        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        AgentboxConfig config = AgentboxConfig(state.configContract);

        uint256 mapWidth = config.mapWidth();
        uint256 mapHeight = config.mapHeight();

        role.position.x = uint32(uint256(keccak256(abi.encode(randomWord, 1))) % mapWidth);
        role.position.y = uint32(uint256(keccak256(abi.encode(randomWord, 2))) % mapHeight);
        role.attributes.hp = role.attributes.maxHp;
        role.state = AgentboxStorage.RoleState.Idle;
    }
}