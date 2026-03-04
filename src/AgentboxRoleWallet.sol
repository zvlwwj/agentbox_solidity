// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Errors.sol";

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

interface IAgentboxRole {
    function ownerOf(uint256 tokenId) external view returns (address);
    function controllerOf(uint256 roleId) external view returns (address);
}

contract AgentboxRoleWallet is Initializable, ERC1155Holder, ERC721Holder {
    address public roleContract;
    uint256 public roleId;

    function initialize(address _roleContract, uint256 _roleId) external initializer {
        roleContract = _roleContract;
        roleId = _roleId;
    }

    modifier onlyController() {
        IAgentboxRole role = IAgentboxRole(roleContract);
        address controller = role.controllerOf(roleId);
        if (controller != address(0)) {
            if (!(msg.sender == controller)) revert NotController();
        } else {
            if (!(msg.sender == role.ownerOf(roleId))) revert NotOwner();
        }
        _;
    }

    function execute(address to, uint256 value, bytes calldata data) external onlyController returns (bytes memory) {
        (bool success, bytes memory result) = to.call{value: value}(data);
        if (!(success)) revert CallFailed();
        return result;
    }
    
    receive() external payable {}
}
