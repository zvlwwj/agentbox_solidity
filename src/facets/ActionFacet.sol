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
    }

    function startMove(address roleWallet, uint256 targetX, uint256 targetY) external onlyRoleController(roleWallet) {
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

        role.state = AgentboxStorage.RoleState.Moving;
        role.moving = AgentboxStorage.MovingState({
            startBlock: uint64(block.number),
            requiredBlocks: uint64(requiredBlocks),
            targetPosition: AgentboxStorage.Position(uint32(targetX), uint32(targetY))
        });

        emit ActionStarted(roleWallet, "Move");
    }

    function finishMove(address roleWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];

        if (!(role.state == AgentboxStorage.RoleState.Moving)) revert RoleNotMoving();
        if (!(block.number >= role.moving.startBlock + role.moving.requiredBlocks)) revert MoveNotFinishedYet();

        role.position = role.moving.targetPosition;
        role.state = AgentboxStorage.RoleState.Idle;

        if (state.economyContract != address(0)) {
            AgentboxEconomy economy = AgentboxEconomy(state.economyContract);
            economy.pickupTokens(roleWallet, role.position.x, role.position.y);
        }

        emit ActionFinished(roleWallet, "Move");
    }

    function attack(address roleWallet, address targetWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage attacker = state.roles[roleWallet];
        AgentboxStorage.RoleData storage target = state.roles[targetWallet];

        if (!(attacker.state == AgentboxStorage.RoleState.Idle)) revert AttackerNotIdle();
        if (!(target.attributes.hp > 0)) revert TargetAlreadyDead();

        AgentboxConfig config = AgentboxConfig(state.configContract);
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

        if (!(dx + dy <= attacker.attributes.range)) revert TargetOutOfRange();

        uint256 damage = attacker.attributes.attack > target.attributes.defense
            ? attacker.attributes.attack - target.attributes.defense
            : 0;

        if (damage >= target.attributes.hp) {
            target.attributes.hp = 0;

            // Cleanup linked states on death to prevent stuck states
            if (target.state == AgentboxStorage.RoleState.Learning) {
                if (target.learning.isNPC) {
                    AgentboxStorage.NPC storage npc = state.npcs[target.learning.targetId];
                    if (npc.studentId == uint160(targetWallet)) {
                        npc.isTeaching = false;
                    }
                } else {
                    address teacherWallet = target.learning.teacherWallet;
                    AgentboxStorage.RoleData storage teacher = state.roles[teacherWallet];
                    if (teacher.state == AgentboxStorage.RoleState.Teaching && teacher.teaching.studentWallet == targetWallet) {
                        teacher.state = AgentboxStorage.RoleState.Idle;
                    }
                }
            } else if (target.state == AgentboxStorage.RoleState.Teaching) {
                address studentWallet = target.teaching.studentWallet;
                AgentboxStorage.RoleData storage student = state.roles[studentWallet];
                if (student.state == AgentboxStorage.RoleState.Learning && student.learning.teacherWallet == targetWallet) {
                    student.state = AgentboxStorage.RoleState.Idle;
                }
            }
            
            // Cleanup any other states (gathering, crafting, moving)
            target.state = AgentboxStorage.RoleState.Idle;

            if (state.economyContract != address(0)) {
                AgentboxEconomy(state.economyContract).transferUnreliableOnDeath(targetWallet, roleWallet);
            }
            if (state.randomizerContract != address(0)) {
                // Pass roleId for randomizer
                uint256 targetId = AgentboxRoleWallet(payable(targetWallet)).roleId();
                (bool success,) =
                    state.randomizerContract.call(abi.encodeWithSignature("requestRespawn(uint256)", targetId));
                if (!(success)) revert RandomizerRequestFailed();
            }
        } else {
            target.attributes.hp -= uint32(damage);
        }

        emit Attacked(roleWallet, targetWallet, damage);
    }
}