// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AgentboxConfig.sol";
import "../src/AgentboxRoleWallet.sol";
import "../src/AgentboxRole.sol";
import "../src/AgentboxRandomizer.sol";
import "../src/AgentboxEconomy.sol";
import "../src/AgentboxResource.sol";
import "../src/AgentboxLand.sol";
import "../src/proxy/AgentboxDiamond.sol";
import "../src/facets/AdminFacet.sol";
import "../src/facets/ActionFacet.sol";
import "../src/facets/GatherCraftFacet.sol";
import "../src/facets/LearnFacet.sol";
import "../src/facets/MapFacet.sol";
import "../src/facets/ReadFacet.sol";
import "../src/facets/RoleFacet.sol";
import "../src/facets/SocialFacet.sol";
import "../src/facets/DiamondLoupeFacet.sol";
import "../src/interfaces/IAgentboxCore.sol";
import "../src/Errors.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract AgentboxCoreTest is Test {
    event CharacterProfileSet(address indexed roleWallet, string nickname, uint8 gender);
    event RoleMoved(address indexed roleWallet, uint256 x, uint256 y);

    AgentboxConfig config;
    AgentboxRoleWallet walletImpl;
    AgentboxRole roleToken;
    VRFCoordinatorV2_5Mock vrfMock;
    AgentboxRandomizer randomizer;
    AgentboxEconomy economy;
    AgentboxResource resource;
    AgentboxLand land;
    IAgentboxCore core;

    address player1 = address(0x111);
    address player2 = address(0x222);
    uint256 subId;

    function setUp() public {
        vm.deal(player1, 10 ether);
        vm.deal(player2, 10 ether);

        // Deploy config
        config = new AgentboxConfig();

        // Deploy role system
        walletImpl = new AgentboxRoleWallet();
        roleToken = new AgentboxRole(address(walletImpl));

        // Deploy VRF Mock
        vrfMock = new VRFCoordinatorV2_5Mock(0.1 ether, 1e9, 4e15);
        subId = vrfMock.createSubscription();
        vrfMock.fundSubscription(subId, 100 ether);

        // Deploy Randomizer
        randomizer = new AgentboxRandomizer(address(vrfMock), bytes32(0), subId);
        vrfMock.addConsumer(subId, address(randomizer));

        // Deploy Economy
        economy = new AgentboxEconomy(address(config), address(vrfMock), bytes32(0), subId);
        vrfMock.addConsumer(subId, address(economy));

        // Deploy Resource
        resource = new AgentboxResource();
        land = new AgentboxLand();

        // Deploy Diamond
        AgentboxDiamond diamond = new AgentboxDiamond();
        
        // Deploy Facets
        AdminFacet adminFacet = new AdminFacet();
        ActionFacet actionFacet = new ActionFacet();
        GatherCraftFacet gatherCraftFacet = new GatherCraftFacet();
        LearnFacet learnFacet = new LearnFacet();
        MapFacet mapFacet = new MapFacet();
        ReadFacet readFacet = new ReadFacet();
        RoleFacet roleFacet = new RoleFacet();
        SocialFacet socialFacet = new SocialFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();

        // Build Diamond Cut
        AgentboxDiamond.FacetCut[] memory cuts = new AgentboxDiamond.FacetCut[](9);
        
        bytes4[] memory adminSelectors = new bytes4[](7);
        adminSelectors[0] = AdminFacet.initialize.selector;
        adminSelectors[1] = AdminFacet.withdrawEth.selector;
        adminSelectors[2] = AdminFacet.setResourcePoint.selector;
        adminSelectors[3] = AdminFacet.setSkillBlocks.selector;
        adminSelectors[4] = AdminFacet.setNPC.selector;
        adminSelectors[5] = AdminFacet.setRecipe.selector;
        adminSelectors[6] = AdminFacet.setEquipmentConfig.selector;
        cuts[0] = AgentboxDiamond.FacetCut({facetAddress: address(adminFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: adminSelectors});

        bytes4[] memory actionSelectors = new bytes4[](4);
        actionSelectors[0] = ActionFacet.move.selector;
        actionSelectors[1] = ActionFacet.startTeleport.selector;
        actionSelectors[2] = ActionFacet.finishTeleport.selector;
        actionSelectors[3] = ActionFacet.attack.selector;
        cuts[1] = AgentboxDiamond.FacetCut({facetAddress: address(actionFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: actionSelectors});

        bytes4[] memory gatherCraftSelectors = new bytes4[](7);
        gatherCraftSelectors[0] = GatherCraftFacet.gather.selector;
        gatherCraftSelectors[1] = GatherCraftFacet.startGather.selector;
        gatherCraftSelectors[2] = GatherCraftFacet.finishGather.selector;
        gatherCraftSelectors[3] = GatherCraftFacet.startCrafting.selector;
        gatherCraftSelectors[4] = GatherCraftFacet.finishCrafting.selector;
        gatherCraftSelectors[5] = GatherCraftFacet.equip.selector;
        gatherCraftSelectors[6] = GatherCraftFacet.unequip.selector;
        cuts[2] = AgentboxDiamond.FacetCut({facetAddress: address(gatherCraftFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: gatherCraftSelectors});

        bytes4[] memory learnSelectors = new bytes4[](6);
        learnSelectors[0] = LearnFacet.startLearning.selector;
        learnSelectors[1] = LearnFacet.requestLearningFromPlayer.selector;
        learnSelectors[2] = LearnFacet.acceptTeaching.selector;
        learnSelectors[3] = LearnFacet.cancelLearning.selector;
        learnSelectors[4] = LearnFacet.finishLearning.selector;
        learnSelectors[5] = IAgentboxCore.processNPCRefresh.selector;
        cuts[3] = AgentboxDiamond.FacetCut({facetAddress: address(learnFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: learnSelectors});

        bytes4[] memory mapSelectors = new bytes4[](4);
        mapSelectors[0] = MapFacet.getEntityPosition.selector;
        mapSelectors[1] = MapFacet.buyLand.selector;
        mapSelectors[2] = MapFacet.sellLand.selector;
        mapSelectors[3] = MapFacet.setLandContract.selector;
        cuts[4] = AgentboxDiamond.FacetCut({facetAddress: address(mapFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: mapSelectors});

        bytes4[] memory readSelectors = new bytes4[](19);
        readSelectors[0] = ReadFacet.getCoreContracts.selector;
        readSelectors[1] = ReadFacet.getGlobalConfig.selector;
        readSelectors[2] = ReadFacet.getRoleIdentity.selector;
        readSelectors[3] = ReadFacet.getRoleSnapshot.selector;
        readSelectors[4] = ReadFacet.getRoleProfile.selector;
        readSelectors[5] = ReadFacet.getRoleWalletByNickname.selector;
        readSelectors[6] = ReadFacet.getRoleActionSnapshot.selector;
        readSelectors[7] = ReadFacet.getRoleSkill.selector;
        readSelectors[8] = ReadFacet.getRoleSkills.selector;
        readSelectors[9] = ReadFacet.getEquipped.selector;
        readSelectors[10] = ReadFacet.getEquippedBatch.selector;
        readSelectors[11] = ReadFacet.getLandSnapshot.selector;
        readSelectors[12] = ReadFacet.getLandSnapshotById.selector;
        readSelectors[13] = ReadFacet.getNpcSnapshot.selector;
        readSelectors[14] = ReadFacet.getRecipeSnapshot.selector;
        readSelectors[15] = ReadFacet.getEquipmentSnapshot.selector;
        readSelectors[16] = ReadFacet.getSkillRequiredBlocks.selector;
        readSelectors[17] = ReadFacet.getEconomyBalances.selector;
        readSelectors[18] = ReadFacet.canFinishCurrentAction.selector;
        cuts[5] = AgentboxDiamond.FacetCut({facetAddress: address(readFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: readSelectors});

        bytes4[] memory roleSelectors = new bytes4[](4);
        roleSelectors[0] = bytes4(keccak256("registerCharacter(uint256)"));
        roleSelectors[1] = bytes4(keccak256("registerCharacter(uint256,string,uint8)"));
        roleSelectors[2] = IAgentboxCore.processSpawn.selector;
        roleSelectors[3] = IAgentboxCore.processRespawn.selector;
        cuts[6] = AgentboxDiamond.FacetCut({facetAddress: address(roleFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: roleSelectors});

        bytes4[] memory socialSelectors = new bytes4[](2);
        socialSelectors[0] = SocialFacet.sendMessage.selector;
        socialSelectors[1] = SocialFacet.sendGlobalMessage.selector;
        cuts[7] = AgentboxDiamond.FacetCut({facetAddress: address(socialFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: socialSelectors});

        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        cuts[8] = AgentboxDiamond.FacetCut({facetAddress: address(diamondLoupeFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: loupeSelectors});

        // Execute Cut
        diamond.diamondCut(cuts);

        // Initialize Core via Diamond
        core = IAgentboxCore(address(diamond));
        core.initialize(address(roleToken), address(config), address(economy), address(randomizer), address(resource), address(land));
        
        // Set GameCore references
        resource.setGameCore(address(core));
        land.setGameCore(address(core));
        randomizer.setGameCore(address(core));
        economy.setGameCore(address(core));
    }

    function test_RegisterCharacter() public {
        vm.startPrank(player1);

        uint256 roleId = roleToken.mint();
        address walletAddr = roleToken.wallets(roleId);
        assertTrue(walletAddr != address(0), "Wallet not created");

        // Register
        core.registerCharacter{value: 0.01 ether}(roleId);

        // Check state
        (bool isValid, uint256 x, uint256 y) = core.getEntityPosition(walletAddr);
        // Initially should be (0,0) and state PendingSpawn (since VRF not fulfilled yet)
        assertFalse(isValid, "Should not be fully valid until VRF resolves"); 

        vm.stopPrank();

        // Fulfill VRF for spawn
        vrfMock.fulfillRandomWords(1, address(randomizer));

        (isValid, x, y) = core.getEntityPosition(walletAddr);
        assertTrue(isValid, "Character should be valid after spawn");
    }

    function test_RegisterCharacterWithProfile() public {
        vm.startPrank(player1);

        uint256 roleId = roleToken.mint();
        address walletAddr = roleToken.wallets(roleId);

        vm.expectEmit(true, false, false, true);
        emit CharacterProfileSet(walletAddr, "alpha123", 1);
        core.registerCharacter{value: 0.01 ether}(roleId, "alpha123", 1);
        vm.stopPrank();

        IAgentboxCore.RoleProfileSnapshot memory profile = core.getRoleProfile(walletAddr);
        assertEq(profile.nickname, "alpha123", "Nickname should be stored");
        assertEq(profile.gender, 1, "Gender should be stored");
        assertEq(core.getRoleWalletByNickname("alpha123"), walletAddr, "Nickname lookup should resolve role wallet");
    }

    function test_RegisterCharacterRejectsDuplicateNickname() public {
        vm.startPrank(player1);
        uint256 roleId1 = roleToken.mint();
        core.registerCharacter{value: 0.01 ether}(roleId1, "sharedname", 1);
        vm.stopPrank();

        vm.startPrank(player2);
        uint256 roleId2 = roleToken.mint();
        vm.expectRevert(NicknameAlreadyTaken.selector);
        core.registerCharacter{value: 0.01 ether}(roleId2, "sharedname", 2);
        vm.stopPrank();
    }

    function test_RegisterCharacterRejectsInvalidNicknameLength() public {
        vm.startPrank(player1);
        uint256 roleId = roleToken.mint();
        vm.expectRevert(InvalidNicknameLength.selector);
        core.registerCharacter{value: 0.01 ether}(roleId, "ab", 1);
        vm.stopPrank();
    }

    function test_Movement() public {
        vm.startPrank(player1);
        uint256 roleId = roleToken.mint();
        address walletAddr = roleToken.wallets(roleId);
        core.registerCharacter{value: 0.01 ether}(roleId);
        vm.stopPrank();

        vrfMock.fulfillRandomWords(1, address(randomizer));

        // Start movement
        vm.startPrank(player1);
        core.startTeleport(walletAddr, 100, 100);
        vm.stopPrank();

        // Mine blocks to pass movement time
        vm.roll(block.number + 100000);

        vm.startPrank(player1);
        core.finishTeleport(walletAddr);
        vm.stopPrank();

        (bool isValid, uint256 x, uint256 y) = core.getEntityPosition(walletAddr);
        assertTrue(isValid, "Should be valid");
        assertEq(x, 100, "X should be 100");
        assertEq(y, 100, "Y should be 100");
    }

    function test_ImmediateMoveEmitsRoleMoved() public {
        vm.startPrank(player1);
        uint256 roleId = roleToken.mint();
        address walletAddr = roleToken.wallets(roleId);
        core.registerCharacter{value: 0.01 ether}(roleId);
        vm.stopPrank();

        vrfMock.fulfillRandomWords(1, address(randomizer));

        (, uint256 startX, uint256 startY) = core.getEntityPosition(walletAddr);
        uint256 expectedX = (startX + 1) % config.mapWidth();

        vm.expectEmit(true, false, false, true);
        emit RoleMoved(walletAddr, expectedX, startY);

        vm.prank(player1);
        core.move(walletAddr, 1, 0);

        (, uint256 endX, uint256 endY) = core.getEntityPosition(walletAddr);
        assertEq(endX, expectedX, "X should increment by 1 with wraparound");
        assertEq(endY, startY, "Y should stay the same");
    }

    function test_LandIsERC721Tradable() public {
        vm.startPrank(player1);
        uint256 roleId1 = roleToken.mint();
        address wallet1 = roleToken.wallets(roleId1);
        core.registerCharacter{value: 0.01 ether}(roleId1);
        vm.stopPrank();

        vm.startPrank(player2);
        uint256 roleId2 = roleToken.mint();
        address wallet2 = roleToken.wallets(roleId2);
        core.registerCharacter{value: 0.01 ether}(roleId2);
        vm.stopPrank();

        vrfMock.fulfillRandomWords(1, address(randomizer));
        vrfMock.fulfillRandomWords(2, address(randomizer));

        (, uint256 x1, uint256 y1) = core.getEntityPosition(wallet1);
        uint256 landId = y1 * config.mapWidth() + x1;
        assertEq(land.ownerOf(landId), wallet1, "Spawn land should mint to role wallet");

        vm.expectRevert(SpatialHookPositionsMustMatch.selector);
        vm.prank(wallet1);
        land.safeTransferFrom(wallet1, wallet2, landId);

        vm.startPrank(player2);
        core.startTeleport(wallet2, x1, y1);
        vm.stopPrank();
        vm.roll(block.number + 100000);
        vm.startPrank(player2);
        core.finishTeleport(wallet2);
        vm.stopPrank();

        vm.prank(wallet1);
        land.safeTransferFrom(wallet1, wallet2, landId);

        assertEq(land.ownerOf(landId), wallet2, "Land should transfer when wallets are co-located");
    }
}
