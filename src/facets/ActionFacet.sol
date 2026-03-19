// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Errors.sol";

import "./AgentboxBase.sol";
import "../AgentboxConfig.sol";
import "../AgentboxEconomy.sol";

contract ActionFacet is AgentboxBase {
    function moveTo(address roleWallet, uint256 targetX, uint256 targetY) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];

        if (!(role.state == AgentboxStorage.RoleState.Idle)) revert RoleNotIdle();

        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 mapWidth = config.mapWidth();
        uint256 mapHeight = config.mapHeight();
        if (!(targetX < mapWidth && targetY < mapHeight)) revert TargetOutOfBounds();

        uint256 distance =
            _wrappedManhattanDistance(role.position.x, role.position.y, uint32(targetX), uint32(targetY), mapWidth, mapHeight);
        if (!(distance <= role.attributes.speed)) revert MoveExceedsSpeed();

        role.position.x = uint32(targetX);
        role.position.y = uint32(targetY);

        if (state.economyContract != address(0)) {
            AgentboxEconomy economy = AgentboxEconomy(state.economyContract);
            economy.pickupTokens(roleWallet, role.position.x, role.position.y);
        }

        emit RoleMoved(roleWallet, role.position.x, role.position.y);
    }

    function startTeleport(address roleWallet, uint256 targetX, uint256 targetY) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];

        if (!(role.state == AgentboxStorage.RoleState.Idle)) revert RoleNotIdle();

        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 mapWidth = config.mapWidth();
        uint256 mapHeight = config.mapHeight();
        if (!(targetX < mapWidth && targetY < mapHeight)) revert TargetOutOfBounds();

        uint256 distance = _wrappedManhattanDistance(
            role.position.x, role.position.y, uint32(targetX), uint32(targetY), mapWidth, mapHeight
        );
        
        if (!(distance > 0)) revert AlreadyAtTarget();
        
        uint256 requiredBlocks = (distance + role.attributes.speed - 1) / role.attributes.speed;

        role.state = AgentboxStorage.RoleState.Teleporting;
        role.teleport = AgentboxStorage.TeleportState({
            startBlock: uint64(block.number),
            requiredBlocks: uint64(requiredBlocks),
            targetPosition: AgentboxStorage.Position(uint32(targetX), uint32(targetY))
        });

        emit ActionStarted(roleWallet, "Teleport");
    }

    function finishTeleport(address roleWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];

        if (!(role.state == AgentboxStorage.RoleState.Teleporting)) revert RoleNotTeleporting();
        if (!(block.number >= role.teleport.startBlock + role.teleport.requiredBlocks)) revert TeleportNotFinishedYet();

        role.position = role.teleport.targetPosition;
        role.state = AgentboxStorage.RoleState.Idle;

        if (state.economyContract != address(0)) {
            AgentboxEconomy economy = AgentboxEconomy(state.economyContract);
            economy.pickupTokens(roleWallet, role.position.x, role.position.y);
        }

        emit ActionFinished(roleWallet, "Teleport");
    }

    function attack(address roleWallet, address targetWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage attacker = state.roles[roleWallet];
        AgentboxStorage.RoleData storage target = state.roles[targetWallet];

        if (!(attacker.state == AgentboxStorage.RoleState.Idle)) revert AttackerNotIdle();
        if (!(target.attributes.hp > 0)) revert TargetAlreadyDead();

        if (!_isTargetInRange(state.configContract, attacker, target)) revert TargetOutOfRange();

        uint256 damage = _calculateDamage(attacker, target);

        if (damage >= target.attributes.hp) {
            _handleRoleDeath(state, roleWallet, targetWallet, target);
        } else {
            target.attributes.hp -= uint32(damage);
        }

        emit Attacked(roleWallet, targetWallet, damage);
    }

    function _handleRoleDeath(
        AgentboxStorage.GameState storage state,
        address attackerWallet,
        address targetWallet,
        AgentboxStorage.RoleData storage target
    ) internal {
        target.attributes.hp = 0;
        _cleanupLinkedRoleStates(state, targetWallet, target);
        target.state = AgentboxStorage.RoleState.Idle;

        if (state.economyContract != address(0)) {
            AgentboxEconomy(state.economyContract).transferUnreliableOnDeath(targetWallet, attackerWallet);
        }
        if (state.randomizerContract != address(0)) {
            uint256 targetId = AgentboxRoleWallet(payable(targetWallet)).roleId();
            (bool success,) = state.randomizerContract.call(abi.encodeWithSignature("requestRespawn(uint256)", targetId));
            if (!(success)) revert RandomizerRequestFailed();
        }
    }

    function _cleanupLinkedRoleStates(
        AgentboxStorage.GameState storage state,
        address targetWallet,
        AgentboxStorage.RoleData storage target
    ) internal {
        if (target.state == AgentboxStorage.RoleState.Learning) {
            if (target.learning.isNPC) {
                AgentboxStorage.NPC storage npc = state.npcs[target.learning.targetId];
                if (npc.studentId == uint160(targetWallet)) {
                    npc.isTeaching = false;
                    npc.studentId = 0;
                    npc.startBlock = 0;
                    emit NPCTeachingStateChanged(target.learning.targetId, false, address(0), 0);
                }
            } else {
                address teacherWallet = target.learning.teacherWallet;
                AgentboxStorage.RoleData storage teacher = state.roles[teacherWallet];
                if (teacher.state == AgentboxStorage.RoleState.Teaching && teacher.teaching.studentWallet == targetWallet) {
                    teacher.state = AgentboxStorage.RoleState.Idle;
                    emit ActionFinished(teacherWallet, "TeachPlayer");
                }
            }
        } else if (target.state == AgentboxStorage.RoleState.Teaching) {
            address studentWallet = target.teaching.studentWallet;
            AgentboxStorage.RoleData storage student = state.roles[studentWallet];
            if (student.state == AgentboxStorage.RoleState.Learning && student.learning.teacherWallet == targetWallet) {
                student.state = AgentboxStorage.RoleState.Idle;
                emit ActionFinished(studentWallet, "CancelLearning");
            }
        }
    }

    function _isTargetInRange(
        address configContract,
        AgentboxStorage.RoleData storage attacker,
        AgentboxStorage.RoleData storage target
    ) internal view returns (bool) {
        AgentboxConfig config = AgentboxConfig(configContract);
        return _wrappedManhattanDistance(
            attacker.position.x, attacker.position.y, target.position.x, target.position.y, config.mapWidth(), config.mapHeight()
        ) <= attacker.attributes.range;
    }

    function _calculateDamage(
        AgentboxStorage.RoleData storage attacker,
        AgentboxStorage.RoleData storage target
    ) internal view returns (uint256) {
        return attacker.attributes.attack > target.attributes.defense
            ? attacker.attributes.attack - target.attributes.defense
            : 0;
    }

    function _wrappedManhattanDistance(
        uint32 fromX,
        uint32 fromY,
        uint32 toX,
        uint32 toY,
        uint256 mapWidth,
        uint256 mapHeight
    ) internal pure returns (uint256) {
        return _wrappedAxisDistance(fromX, toX, mapWidth) + _wrappedAxisDistance(fromY, toY, mapHeight);
    }

    function _wrappedAxisDistance(uint32 from, uint32 to, uint256 size) internal pure returns (uint256 distance) {
        distance = from > to ? from - to : to - from;
        if (distance > size / 2) {
            distance = size - distance;
        }
    }
}
