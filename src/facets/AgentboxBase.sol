// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Errors.sol";

import "../storage/AgentboxStorage.sol";
import "../AgentboxRole.sol";
import "../AgentboxRoleWallet.sol";

abstract contract AgentboxBase {
    event CharacterRegistered(uint256 indexed roleId, address indexed roleWallet);
    event CoreContractsUpdated(
        address roleContract,
        address configContract,
        address economyContract,
        address randomizerContract,
        address resourceContract,
        address landContract
    );
    event LandBought(uint256 indexed landId, address indexed owner);
    event LandSold(uint256 indexed landId, address indexed owner);
    event LandContractSet(uint256 indexed landId, address indexed contractAddress);
    event MessageSent(address indexed fromWallet, address indexed toWallet, string message);
    event GlobalMessageSent(address indexed fromWallet, string message);

    event CharacterProfileSet(address indexed roleWallet, string nickname, uint8 gender);
    event ActionStarted(address indexed roleWallet, string actionType);
    event ActionFinished(address indexed roleWallet, string actionType);
    event RoleMoved(address indexed roleWallet, uint256 x, uint256 y);
    event Attacked(address indexed attacker, address indexed target, uint256 damage);
    event Equipped(address indexed roleWallet, uint256 slot, uint256 equipmentId);
    event SkillLearned(
        address indexed roleWallet,
        uint256 indexed skillId,
        bool learnedFromNpc,
        uint256 targetId,
        address teacherWallet
    );
    event NPCTeachingStateChanged(
        uint256 indexed npcId,
        bool isTeaching,
        address studentWallet,
        uint256 startBlock
    );
    event ResourcePointUpdated(
        uint256 indexed landId,
        uint256 indexed x,
        uint256 indexed y,
        uint256 resourceType,
        uint256 stock,
        bool isResourcePoint
    );
    event RoleRespawned(address indexed roleWallet, uint256 x, uint256 y, uint256 hp);

    modifier onlyRoleController(address roleWallet) {
        AgentboxRole roleToken = AgentboxRole(AgentboxStorage.getStorage().roleContract);
        uint256 roleId = AgentboxRoleWallet(payable(roleWallet)).roleId();
        if (!(roleToken.wallets(roleId) == roleWallet)) revert InvalidRoleWallet();

        address controller = roleToken.controllerOf(roleId);
        if (controller != address(0)) {
            if (!(controller == msg.sender)) revert NotController();
        } else {
            if (!(roleToken.ownerOf(roleId) == msg.sender)) revert NotOwner();
        }
        _;
    }

    modifier onlyOwner() {
        if (!(msg.sender == AgentboxStorage.getStorage().owner)) revert NotOwner();
        _;
    }

    modifier onlyRandomizer() {
        if (!(msg.sender == AgentboxStorage.getStorage().randomizerContract)) revert OnlyRandomizer();
        _;
    }
}
