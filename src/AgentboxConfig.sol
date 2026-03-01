// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract AgentboxConfig is Ownable {
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
        mapWidth = width;
        mapHeight = height;
    }

    function setMintIntervalBlocks(uint256 interval) external onlyOwner {
        mintIntervalBlocks = interval;
    }

    function setMintAmount(uint256 amount) external onlyOwner {
        mintAmount = amount;
    }

    function setStabilizationBlocks(uint256 blocks) external onlyOwner {
        stabilizationBlocks = blocks;
    }

    function setCraftDurationBlocks(uint256 blocks) external onlyOwner {
        craftDurationBlocks = blocks;
    }

    function setHalvingIntervalBlocks(uint256 blocks) external onlyOwner {
        halvingIntervalBlocks = blocks;
    }

    function setLandPrice(uint256 price) external onlyOwner {
        landPrice = price;
    }
}
