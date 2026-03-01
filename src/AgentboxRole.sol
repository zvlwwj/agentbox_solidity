// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./AgentboxRoleWallet.sol";

contract AgentboxRole is ERC721, Ownable {
    using Clones for address;

    uint256 private _nextTokenId;
    address public walletImplementation;

    // roleId => controller
    mapping(uint256 => address) private _controllers;
    // roleId => wallet
    mapping(uint256 => address) public wallets;

    event ControllerSet(uint256 indexed roleId, address indexed controller);
    event ControllerCleared(uint256 indexed roleId);
    event WalletCreated(uint256 indexed roleId, address indexed wallet);

    constructor(address _walletImplementation) ERC721("AgentboxRole", "AROLE") Ownable(msg.sender) {
        walletImplementation = _walletImplementation;
    }

    function mint() external returns (uint256) {
        uint256 roleId = _nextTokenId++;
        _mint(msg.sender, roleId);
        
        address clone = walletImplementation.clone();
        AgentboxRoleWallet(payable(clone)).initialize(address(this), roleId);
        wallets[roleId] = clone;
        
        emit WalletCreated(roleId, clone);
        return roleId;
    }

    function setController(uint256 roleId, address controller) external {
        require(ownerOf(roleId) == msg.sender, "Not the owner");
        _controllers[roleId] = controller;
        emit ControllerSet(roleId, controller);
    }

    function clearController(uint256 roleId) external {
        require(ownerOf(roleId) == msg.sender, "Not the owner");
        delete _controllers[roleId];
        emit ControllerCleared(roleId);
    }

    function controllerOf(uint256 roleId) external view returns (address) {
        return _controllers[roleId];
    }
}
