// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Errors.sol";

import "./AgentboxBase.sol";
import "../AgentboxConfig.sol";
import "../AgentboxEconomy.sol";

contract ActionFacet is AgentboxBase {
    function move(address roleWallet, int256 dx, int256 dy) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];

        if (!(role.state == AgentboxStorage.RoleState.Idle)) revert RoleNotIdle();

        uint256 absDx = dx >= 0 ? uint256(dx) : uint256(-dx);
        uint256 absDy = dy >= 0 ? uint256(dy) : uint256(-dy);
        if (!(absDx + absDy <= role.attributes.speed)) revert MoveExceedsSpeed();

        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 mapWidth = config.mapWidth();
        uint256 mapHeight = config.mapHeight();

        int256 newX = (int256(uint256(role.position.x)) + dx) % int256(mapWidth);
        if (newX < 0) newX += int256(mapWidth);

        int256 newY = (int256(uint256(role.position.y)) + dy) % int256(mapHeight);
        if (newY < 0) newY += int256(mapHeight);

        role.position.x = uint32(uint256(newX));
        role.position.y = uint32(uint256(newY));

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

        uint256 dx = targetX > role.position.x ? targetX - role.position.x : role.position.x - targetX;
        uint256 dy = targetY > role.position.y ? targetY - role.position.y : role.position.y - targetY;
        
        dx = dx > mapWidth / 2 ? mapWidth - dx : dx;
        dy = dy > mapHeight / 2 ? mapHeight - dy : dy;

        uint256 distance = dx + dy;
        
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
        uint256 mapWidth = config.mapWidth();
        uint256 mapHeight = config.mapHeight();

        uint256 dx = attacker.position.x > target.position.x
            ? attacker.position.x - target.position.x
            : target.position.x - attacker.position.x;
        uint256 dy = attacker.position.y > target.position.y
            ? attacker.position.y - target.position.y
            : target.position.y - attacker.position.y;

        dx = dx > mapWidth / 2 ? mapWidth - dx : dx;
        dy = dy > mapHeight / 2 ? mapHeight - dy : dy;

        return dx + dy <= attacker.attributes.range;
    }

    function _calculateDamage(
        AgentboxStorage.RoleData storage attacker,
        AgentboxStorage.RoleData storage target
    ) internal view returns (uint256) {
        return attacker.attributes.attack > target.attributes.defense
            ? attacker.attributes.attack - target.attributes.defense
            : 0;
    }
}
