// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Errors.sol";

import "./AgentboxBase.sol";
import "../AgentboxConfig.sol";

contract LearnFacet is AgentboxBase {
    function startLearning(address roleWallet, uint256 npcId) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        if (!(role.state == AgentboxStorage.RoleState.Idle)) revert RoleNotIdle();

        AgentboxStorage.NPC storage npc = state.npcs[npcId];
        if (!(!npc.isTeaching)) revert NpcIsBusy();
        if (!(npc.position.x == role.position.x && npc.position.y == role.position.y)) revert NotAtNpc();
        
        uint256 reqBlocks = state.skillRequiredBlocks[npc.skillId];
        if (!(reqBlocks > 0)) revert SkillNotConfigured();

        role.state = AgentboxStorage.RoleState.Learning;
        role.learning = AgentboxStorage.LearningState({
            startBlock: uint64(block.number),
            requiredBlocks: uint64(reqBlocks),
            targetId: uint32(npcId),
            skillId: npc.skillId,
            isNPC: true,
            teacherWallet: address(0)
        });

        npc.isTeaching = true;
        
        // Let's store studentId as uint256 representation of wallet, or just cast it
        npc.studentId = uint160(roleWallet);
        npc.startBlock = uint64(block.number);

        emit ActionStarted(roleWallet, "Learn");
    }

    function requestLearningFromPlayer(address roleWallet, address teacherWallet, uint256 skillId) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        AgentboxStorage.RoleData storage teacher = state.roles[teacherWallet];

        if (!(role.state == AgentboxStorage.RoleState.Idle)) revert StudentNotIdle();
        if (!(role.position.x == teacher.position.x && role.position.y == teacher.position.y)) revert NotAtTeacher();
        if (!(teacher.skills[skillId])) revert TeacherDoesNotHaveSkill();
        if (!(!role.skills[skillId])) revert StudentAlreadyHasSkill();

        uint256 baseReqBlocks = state.skillRequiredBlocks[skillId];
        if (!(baseReqBlocks > 0)) revert SkillNotConfigured();

        uint256 reqBlocks = baseReqBlocks * 2;

        // Set student state to pending
        role.state = AgentboxStorage.RoleState.Learning;
        role.learning = AgentboxStorage.LearningState({
            startBlock: 0, // 0 indicates pending
            requiredBlocks: uint64(reqBlocks),
            targetId: 0,
            skillId: uint32(skillId),
            isNPC: false,
            teacherWallet: teacherWallet
        });

        emit ActionStarted(roleWallet, "RequestLearning");
    }

    function acceptTeaching(address roleWallet, address studentWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage teacher = state.roles[roleWallet];
        AgentboxStorage.RoleData storage student = state.roles[studentWallet];

        if (!(teacher.state == AgentboxStorage.RoleState.Idle)) revert TeacherNotIdle();
        if (!(student.state == AgentboxStorage.RoleState.Learning)) revert StudentNotRequesting();
        if (!(student.learning.teacherWallet == roleWallet)) revert StudentNotRequestingYou();
        if (!(student.learning.startBlock == 0)) revert LearningAlreadyStarted();
        if (!(teacher.position.x == student.position.x && teacher.position.y == student.position.y)) revert NotAtStudent();

        uint256 reqBlocks = student.learning.requiredBlocks;

        student.learning.startBlock = uint64(block.number);

        teacher.state = AgentboxStorage.RoleState.Teaching;
        teacher.teaching = AgentboxStorage.TeachingState({
            startBlock: uint64(block.number),
            requiredBlocks: uint64(reqBlocks),
            studentWallet: studentWallet,
            skillId: student.learning.skillId
        });

        emit ActionStarted(studentWallet, "LearnFromPlayer");
        emit ActionStarted(roleWallet, "TeachPlayer");
    }

    function cancelLearning(address roleWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];

        if (!(role.state == AgentboxStorage.RoleState.Learning)) revert NotLearning();
        if (!(!role.learning.isNPC)) revert CannotCancelNpcLearning();
        if (!(role.learning.startBlock == 0)) revert LearningAlreadyStarted();

        role.state = AgentboxStorage.RoleState.Idle;
        emit ActionFinished(roleWallet, "CancelLearning");
    }

    function cancelTeaching(address roleWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage teacher = state.roles[roleWallet];

        if (!(teacher.state == AgentboxStorage.RoleState.Teaching)) revert NotTeaching();

        address studentWallet = teacher.teaching.studentWallet;
        AgentboxStorage.RoleData storage student = state.roles[studentWallet];

        teacher.state = AgentboxStorage.RoleState.Idle;

        if (student.state == AgentboxStorage.RoleState.Learning && student.learning.teacherWallet == roleWallet) {
            student.state = AgentboxStorage.RoleState.Idle;
            emit ActionFinished(studentWallet, "CancelLearning");
        }

        emit ActionFinished(roleWallet, "CancelTeaching");
    }

    function finishLearning(address roleWallet) external {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        if (!(role.state == AgentboxStorage.RoleState.Learning)) revert NotLearning();
        if (!(role.learning.startBlock != 0)) revert LearningNotAcceptedYet();
        if (!(block.number >= role.learning.startBlock + role.learning.requiredBlocks)) revert LearningNotFinished();

        role.state = AgentboxStorage.RoleState.Idle;
        role.skills[role.learning.skillId] = true;

        if (role.learning.isNPC) {
            AgentboxStorage.NPC storage npc = state.npcs[role.learning.targetId];
            npc.isTeaching = false;

            if (state.randomizerContract != address(0)) {
                (bool success,) = state.randomizerContract.call(
                    abi.encodeWithSignature("requestNPCRefresh(uint256)", role.learning.targetId)
                );
                if (!(success)) revert RandomizerRequestFailed();
            }
        } else {
            AgentboxStorage.RoleData storage teacher = state.roles[role.learning.teacherWallet];
            if (teacher.state == AgentboxStorage.RoleState.Teaching && teacher.teaching.studentWallet == roleWallet) {
                teacher.state = AgentboxStorage.RoleState.Idle;
                emit ActionFinished(role.learning.teacherWallet, "TeachPlayer");
            }
        }

        emit ActionFinished(roleWallet, "Learn");
    }

    function processNPCRefresh(uint256 npcId, uint256 randomWord) external onlyRandomizer {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.NPC storage npc = state.npcs[npcId];
        AgentboxConfig config = AgentboxConfig(state.configContract);

        npc.position.x = uint32(uint256(keccak256(abi.encode(randomWord, 1))) % config.mapWidth());
        npc.position.y = uint32(uint256(keccak256(abi.encode(randomWord, 2))) % config.mapHeight());
    }
}