// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ICorePosition {
    function getEntityPosition(address entity) external view returns (bool isValid, uint256 x, uint256 y);
}

contract AgentboxResource is ERC1155, Ownable {
    address public gameCore;

    constructor() ERC1155("") Ownable(msg.sender) {}

    function setGameCore(address _core) external onlyOwner {
        gameCore = _core;
    }

    modifier onlyCore() {
        require(msg.sender == gameCore, "Only game core");
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
            require(fromValid, "Spatial hook: 'from' entity not registered");
            
            (bool toValid, uint256 toX, uint256 toY) = ICorePosition(gameCore).getEntityPosition(to);
            require(toValid, "Spatial hook: 'to' entity not registered");

            require(fromX == toX && fromY == toY, "Spatial hook: positions must match");
        }
        super._update(from, to, ids, values);
    }
}
