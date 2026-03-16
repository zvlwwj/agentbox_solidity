// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Errors.sol";

import "./AgentboxBase.sol";
import "../AgentboxConfig.sol";
import "../AgentboxLand.sol";

contract RoleFacet is AgentboxBase {
    uint256 private constant MIN_NICKNAME_LENGTH = 3;
    uint256 private constant MAX_NICKNAME_LENGTH = 24;

    function registerCharacter(uint256 roleId) external payable {
        _registerCharacter(roleId, "", 0, false);
    }

    function registerCharacter(uint256 roleId, string calldata nickname, uint8 gender) external payable {
        _registerCharacter(roleId, nickname, gender, true);
    }

    function _registerCharacter(uint256 roleId, string memory nickname, uint8 gender, bool withProfile) internal {
        if (!(msg.value == 0.01 ether)) revert Requires001EthToRegister();

        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxRole roleToken = AgentboxRole(state.roleContract);
        if (!(roleToken.ownerOf(roleId) == msg.sender)) revert NotOwner();

        address roleWallet = roleToken.wallets(roleId);
        if (!(roleWallet != address(0))) revert WalletNotDeployed();

        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        if (!(role.attributes.maxHp == 0 && role.state != AgentboxStorage.RoleState.PendingSpawn)) revert AlreadyRegisteredOrPending();

        if (withProfile) {
            _setRoleProfile(state, roleWallet, role, nickname, gender);
            emit CharacterProfileSet(roleWallet, nickname, gender);
        }

        role.state = AgentboxStorage.RoleState.PendingSpawn;

        if (state.randomizerContract != address(0)) {
            (bool success,) = state.randomizerContract.call(abi.encodeWithSignature("requestSpawn(uint256)", roleId));
            if (!(success)) revert RandomizerRequestFailed();
        } else {
            // Fallback for testing without randomizer (though not recommended for prod)
            _finalizeSpawn(roleId, uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))));
        }
    }

    function _setRoleProfile(
        AgentboxStorage.GameState storage state,
        address roleWallet,
        AgentboxStorage.RoleData storage role,
        string memory nickname,
        uint8 gender
    ) internal {
        uint256 nicknameLength = bytes(nickname).length;
        if (nicknameLength < MIN_NICKNAME_LENGTH || nicknameLength > MAX_NICKNAME_LENGTH) revert InvalidNicknameLength();
        if (gender > 2) revert InvalidGender();

        bytes32 nicknameHash = keccak256(bytes(nickname));
        address existingOwner = state.nicknameOwners[nicknameHash];
        if (existingOwner != address(0) && existingOwner != roleWallet) revert NicknameAlreadyTaken();

        state.nicknameOwners[nicknameHash] = roleWallet;
        role.nickname = nickname;
        role.gender = gender;
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

        if (state.totalRegistered < 2000) {
            uint256 landId = startY * mapWidth + startX;
            AgentboxLand landToken = AgentboxLand(state.landContract);
            if (!_isLandOwned(landToken, landId)) {
                landToken.mint(roleWallet, landId);
                emit LandBought(landId, roleWallet);
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

        emit RoleRespawned(roleWallet, role.position.x, role.position.y, role.attributes.hp);
    }

    function _isLandOwned(AgentboxLand landToken, uint256 landId) internal view returns (bool) {
        try landToken.ownerOf(landId) returns (address) {
            return true;
        } catch {
            return false;
        }
    }
}
