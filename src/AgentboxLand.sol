// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Errors.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ICoreLandPosition {
    function getEntityPosition(address entity) external view returns (bool isValid, uint256 x, uint256 y);
}

contract AgentboxLand is ERC721, Ownable {
    address public gameCore;
    event GameCoreSet(address indexed gameCore);

    constructor() ERC721("AgentboxLand", "ALAND") Ownable(msg.sender) {}

    modifier onlyCore() {
        if (!(msg.sender == gameCore)) revert OnlyGameCore();
        _;
    }

    function setGameCore(address _core) external onlyOwner {
        gameCore = _core;
        emit GameCoreSet(_core);
    }

    function mint(address to, uint256 landId) external onlyCore {
        _mint(to, landId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            (bool fromValid, uint256 fromX, uint256 fromY) = ICoreLandPosition(gameCore).getEntityPosition(from);
            if (!(fromValid)) revert SpatialHookFromEntityNotRegistered();

            (bool toValid, uint256 toX, uint256 toY) = ICoreLandPosition(gameCore).getEntityPosition(to);
            if (!(toValid)) revert SpatialHookToEntityNotRegistered();

            if (!(fromX == toX && fromY == toY)) revert SpatialHookPositionsMustMatch();
        }
        return super._update(to, tokenId, auth);
    }
}
