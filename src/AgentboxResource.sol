// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Errors.sol";

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ICorePosition {
    function getEntityPosition(address entity) external view returns (bool isValid, uint256 x, uint256 y);
}

contract AgentboxResource is ERC1155, Ownable {
    address public gameCore;
    event GameCoreSet(address indexed gameCore);

    constructor() ERC1155("") Ownable(msg.sender) {}

    function setGameCore(address _core) external onlyOwner {
        gameCore = _core;
        emit GameCoreSet(_core);
    }

    modifier onlyCore() {
        if (!(msg.sender == gameCore)) revert OnlyGameCore();
        _;
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyCore {
        _mint(to, id, amount, data);
    }

    function burn(address from, uint256 id, uint256 amount) external onlyCore {
        _burn(from, id, amount);
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override {
        if (from != address(0) && to != address(0)) {
            (bool fromValid, uint256 fromX, uint256 fromY) = ICorePosition(gameCore).getEntityPosition(from);
            if (!(fromValid)) revert SpatialHookFromEntityNotRegistered();
            
            (bool toValid, uint256 toX, uint256 toY) = ICorePosition(gameCore).getEntityPosition(to);
            if (!(toValid)) revert SpatialHookToEntityNotRegistered();

            if (!(fromX == toX && fromY == toY)) revert SpatialHookPositionsMustMatch();
        }
        super._update(from, to, ids, values);
    }
}
