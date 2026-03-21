// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Errors.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./AgentboxRoleWallet.sol";

contract AgentboxRole is ERC721, Ownable {
    using Clones for address;

    uint256 private _nextTokenId;
    address public gameCore;
    address public walletImplementation;

    // roleId => controller
    mapping(uint256 => address) private _controllers;
    // roleId => wallet
    mapping(uint256 => address) public wallets;
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    mapping(uint256 => uint256) private _ownedTokensIndex;

    event ControllerSet(uint256 indexed roleId, address indexed controller);
    event ControllerCleared(uint256 indexed roleId);
    event WalletCreated(uint256 indexed roleId, address indexed wallet);

    constructor(address _walletImplementation) ERC721("AgentboxRole", "AROLE") Ownable(msg.sender) {
        walletImplementation = _walletImplementation;
    }

    function setGameCore(address _gameCore) external onlyOwner {
        gameCore = _gameCore;
    }

    function mintTo(address to) external returns (uint256) {
        if (msg.sender != gameCore) revert OnlyGameCore();

        uint256 roleId = _nextTokenId++;
        _mint(to, roleId);

        address clone = walletImplementation.clone();
        AgentboxRoleWallet(payable(clone)).initialize(address(this), roleId);
        wallets[roleId] = clone;

        emit WalletCreated(roleId, clone);
        return roleId;
    }

    function setController(uint256 roleId, address controller) external {
        if (!(ownerOf(roleId) == msg.sender)) revert NotTheOwner();
        _controllers[roleId] = controller;
        emit ControllerSet(roleId, controller);
    }

    function clearController(uint256 roleId) external {
        if (!(ownerOf(roleId) == msg.sender)) revert NotTheOwner();
        delete _controllers[roleId];
        emit ControllerCleared(roleId);
    }

    function controllerOf(uint256 roleId) external view returns (address) {
        return _controllers[roleId];
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256) {
        if (!(index < balanceOf(owner))) revert NotOwner();
        return _ownedTokens[owner][index];
    }

    function totalMinted() external view returns (uint256) {
        return _nextTokenId;
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address previousOwner) {
        previousOwner = super._update(to, tokenId, auth);

        if (previousOwner != address(0)) {
            _removeTokenFromOwnerEnumeration(previousOwner, tokenId);
        }

        if (to != address(0)) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = balanceOf(to) - 1;
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        uint256 lastTokenIndex = balanceOf(from);
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];
            _ownedTokens[from][tokenIndex] = lastTokenId;
            _ownedTokensIndex[lastTokenId] = tokenIndex;
        }

        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }
}
