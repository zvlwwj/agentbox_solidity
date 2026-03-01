// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AgentboxRole.sol";
import "../src/AgentboxConfig.sol";
import "../src/AgentboxEconomy.sol";
import "../src/AgentboxCore.sol";
import "../src/AgentboxRandomizer.sol";
import "../src/AgentboxResource.sol";
import "./MockMarket.sol";
import "../src/AgentboxRoleWallet.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockVRFCoordinator {
    function requestRandomWords(bytes32, uint64, uint16, uint32, uint32) external pure returns (uint256 requestId) {
        return 1;
    }
}

contract AgentboxTest is Test {
    AgentboxRole role;
    AgentboxConfig config;
    AgentboxEconomy economy;
    AgentboxResource resource;
    AgentboxCore core;
    AgentboxRandomizer randomizer;
    MockVRFCoordinator mockVrf;

    address alice = address(0x1111);
    address bob = address(0x2222);

    function setUp() public {
        vm.startPrank(alice);
        
        AgentboxRoleWallet walletImpl = new AgentboxRoleWallet();
        role = new AgentboxRole(address(walletImpl));
        config = new AgentboxConfig();
        mockVrf = new MockVRFCoordinator();
        resource = new AgentboxResource();

        economy = new AgentboxEconomy(address(config), address(mockVrf), bytes32(0), 0);
        randomizer = new AgentboxRandomizer(address(mockVrf), bytes32(0), 0);

        AgentboxCore coreImpl = new AgentboxCore();
        bytes memory data = abi.encodeCall(
            AgentboxCore.initialize, (address(role), address(config), address(economy), address(randomizer), address(resource))
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(coreImpl), data);
        core = AgentboxCore(address(proxy));

        economy.setGameCore(address(core));
        randomizer.setGameCore(address(core));
        resource.setGameCore(address(core));

        vm.stopPrank();
    }

    function testRoleMintAndRegister() public {
        vm.startPrank(alice);
        uint256 roleId = role.mint();
        address wallet = role.wallets(roleId);
        assertEq(role.ownerOf(roleId), alice);

        core.registerCharacter(roleId);

        (bool isValid, uint256 x, uint256 y) = core.getEntityPosition(wallet);
        assertTrue(isValid);
        assertEq(x, 0);
        assertEq(y, 0);
        vm.stopPrank();
    }

    function testMovement() public {
        vm.startPrank(alice);
        uint256 roleId = role.mint();
        address wallet = role.wallets(roleId);
        core.registerCharacter(roleId);

        core.move(wallet, 1, 2);
        (bool isValid, uint256 x, uint256 y) = core.getEntityPosition(wallet);
        assertTrue(isValid);
        assertEq(x, 1);
        assertEq(y, 2);
        vm.stopPrank();
    }

    function testAttack() public {
        vm.startPrank(alice);
        uint256 attackerId = role.mint();
        address attackerWallet = role.wallets(attackerId);
        core.registerCharacter(attackerId);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 targetId = role.mint();
        address targetWallet = role.wallets(targetId);
        core.registerCharacter(targetId);
        vm.stopPrank();

        vm.startPrank(alice);
        core.attack(attackerWallet, targetWallet);
        vm.stopPrank();
    }

    function testLandContractAndTransfer() public {
        vm.startPrank(alice);
        uint256 sellerId = role.mint();
        address sellerWallet = role.wallets(sellerId);
        core.registerCharacter(sellerId);
        vm.stopPrank();

        // Give seller some money to buy land
        deal(address(economy), sellerWallet, 200 * 10**18);

        vm.startPrank(sellerWallet);
        economy.approve(address(core), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(alice);
        core.buyLand(sellerWallet, 0, 0);

        MockMarket market = new MockMarket(address(core), address(economy), address(resource));
        core.setLandContract(0, 0, address(market));
        vm.stopPrank();

        // Mock seller having resource
        vm.prank(address(core));
        resource.mint(sellerWallet, 1, 100, "");

        vm.startPrank(sellerWallet);
        resource.setApprovalForAll(address(market), true);
        market.listOrder(1, 50, 20 * 10**18);
        vm.stopPrank();

        // Bob arrives and buys
        vm.startPrank(bob);
        uint256 buyerId = role.mint();
        address buyerWallet = role.wallets(buyerId);
        core.registerCharacter(buyerId);
        vm.stopPrank();

        // Give buyer some AGC
        deal(address(economy), buyerWallet, 500 * 10**18);

        vm.startPrank(buyerWallet);
        economy.approve(address(market), type(uint256).max);
        market.buyOrder(0);
        vm.stopPrank();

        assertEq(resource.balanceOf(buyerWallet, 1), 50);
        assertEq(economy.balanceOf(buyerWallet), 480 * 10**18);
    }

    function testRevertSpatialTransfer() public {
        vm.startPrank(alice);
        uint256 sellerId = role.mint();
        address sellerWallet = role.wallets(sellerId);
        core.registerCharacter(sellerId);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 buyerId = role.mint();
        address buyerWallet = role.wallets(buyerId);
        core.registerCharacter(buyerId);
        
        // Bob moves away
        core.move(buyerWallet, 1, 2);
        vm.stopPrank();

        // Alice tries to transfer resource to Bob directly (should fail because coordinates mismatch)
        vm.prank(address(core));
        resource.mint(sellerWallet, 1, 100, "");

        vm.startPrank(sellerWallet);
        vm.expectRevert("Spatial hook: positions must match");
        resource.safeTransferFrom(sellerWallet, buyerWallet, 1, 10, "");
        vm.stopPrank();
    }
}
