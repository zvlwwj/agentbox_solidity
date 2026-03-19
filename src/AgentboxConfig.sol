// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Errors.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract AgentboxConfig is Ownable {
    event GlobalConfigUpdated(
        uint256 mapWidth,
        uint256 mapHeight,
        uint256 mintIntervalBlocks,
        uint256 mintAmount,
        uint256 stabilizationBlocks,
        uint256 craftDurationBlocks,
        uint256 halvingIntervalBlocks,
        uint256 landPrice
    );

    uint256 public mapWidth = 10000;
    uint256 public mapHeight = 10000;
    uint256 public mintIntervalBlocks = 100;
    uint256 public mintAmount = 50 * 10 ** 18;
    uint256 public stabilizationBlocks = 4000;
    uint256 public craftDurationBlocks = 3600;
    uint256 public halvingIntervalBlocks = 6048000;
    uint256 public landPrice = 100 * 10 ** 18;

    constructor() Ownable(msg.sender) {}

    function setMapDimensions(uint256 width, uint256 height) external onlyOwner {
        if (!(width > 0 && height > 0)) revert InvalidMapDimensions();
        mapWidth = width;
        mapHeight = height;
        _emitGlobalConfigUpdated();
    }

    function setMintIntervalBlocks(uint256 interval) external onlyOwner {
        mintIntervalBlocks = interval;
        _emitGlobalConfigUpdated();
    }

    function setMintAmount(uint256 amount) external onlyOwner {
        mintAmount = amount;
        _emitGlobalConfigUpdated();
    }

    function setStabilizationBlocks(uint256 blocks) external onlyOwner {
        stabilizationBlocks = blocks;
        _emitGlobalConfigUpdated();
    }

    function setCraftDurationBlocks(uint256 blocks) external onlyOwner {
        craftDurationBlocks = blocks;
        _emitGlobalConfigUpdated();
    }

    function setHalvingIntervalBlocks(uint256 blocks) external onlyOwner {
        halvingIntervalBlocks = blocks;
        _emitGlobalConfigUpdated();
    }

    function setLandPrice(uint256 price) external onlyOwner {
        landPrice = price;
        _emitGlobalConfigUpdated();
    }

    function _emitGlobalConfigUpdated() internal {
        emit GlobalConfigUpdated(
            mapWidth,
            mapHeight,
            mintIntervalBlocks,
            mintAmount,
            stabilizationBlocks,
            craftDurationBlocks,
            halvingIntervalBlocks,
            landPrice
        );
    }
}
