// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Errors.sol";

import "./AgentboxBase.sol";
import "../AgentboxConfig.sol";
import "../AgentboxEconomy.sol";
import "../AgentboxLand.sol";

contract MapFacet is AgentboxBase {
    function getEntityPosition(address entity) external view returns (bool isValid, uint256 x, uint256 y) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxConfig config = AgentboxConfig(state.configContract);
        
        if (state.isLandContract[entity]) {
            uint256 landId = state.contractToLand[entity];
            y = landId / config.mapWidth();
            x = landId % config.mapWidth();
            return (true, x, y);
        } else {
            AgentboxStorage.RoleData storage role = state.roles[entity];
            if (role.attributes.maxHp == 0) {
                return (false, 0, 0);
            }
            return (true, role.position.x, role.position.y);
        }
    }

    function buyLand(address roleWallet, uint256 x, uint256 y) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 mapWidth = config.mapWidth();
        uint256 landId = y * mapWidth + x;
        AgentboxLand landToken = AgentboxLand(state.landContract);

        if (!(!state.resourcePoints[landId].isResourcePoint)) revert CannotBuyResourcePoint();
        if (_isLandOwned(landToken, landId)) revert LandAlreadyOwned();

        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        if (!(role.position.x == x && role.position.y == y)) revert MustBeOnLandToBuy();

        if (state.economyContract != address(0)) {
            AgentboxEconomy economy = AgentboxEconomy(state.economyContract);
            economy.burnReliable(roleWallet, config.landPrice());
        }

        landToken.mint(roleWallet, landId);
        emit LandBought(landId, roleWallet);
    }

    function sellLand(address roleWallet, uint256 x, uint256 y) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 landId = y * config.mapWidth() + x;
        AgentboxLand landToken = AgentboxLand(state.landContract);
        if (!(landToken.ownerOf(landId) == roleWallet)) revert NotTheLandOwner();

        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        if (!(role.position.x == x && role.position.y == y)) revert MustBeOnLandToSell();
        revert LandBurnDisabled();
    }

    function setLandContract(address roleWallet, uint256 x, uint256 y, address contractAddress) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 landId = y * config.mapWidth() + x;
        AgentboxLand landToken = AgentboxLand(state.landContract);
        
        if (!(landToken.ownerOf(landId) == roleWallet)) revert NotLandOwner();
        if (!(!state.isLandContract[contractAddress])) revert ContractAlreadyBound();
        
        address prevContract = state.landContracts[landId];
        if (prevContract != address(0)) {
            state.isLandContract[prevContract] = false;
            state.contractToLand[prevContract] = 0;
        }

        state.landContracts[landId] = contractAddress;
        state.contractToLand[contractAddress] = landId;
        state.isLandContract[contractAddress] = true;
        
        emit LandContractSet(landId, contractAddress);
    }

    function _isLandOwned(AgentboxLand landToken, uint256 landId) internal view returns (bool) {
        try landToken.ownerOf(landId) returns (address) {
            return true;
        } catch {
            return false;
        }
    }
}