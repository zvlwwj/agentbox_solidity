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
        actionSelectors[0] = ActionFacet.moveTo.selector;
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

        bytes4[] memory learnSelectors = new bytes4[](7);
        learnSelectors[0] = LearnFacet.startLearning.selector;
        learnSelectors[1] = LearnFacet.requestLearningFromPlayer.selector;
        learnSelectors[2] = LearnFacet.acceptTeaching.selector;
        learnSelectors[3] = LearnFacet.cancelLearning.selector;
        learnSelectors[4] = LearnFacet.cancelTeaching.selector;
        learnSelectors[5] = LearnFacet.finishLearning.selector;
        learnSelectors[6] = IAgentboxCore.processNPCRefresh.selector;
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
        roleSelectors[0] = bytes4(keccak256("createCharacter()"));
        roleSelectors[1] = bytes4(keccak256("createCharacter(string,uint8)"));
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
        roleToken.setGameCore(address(core));
    }

    function test_RegisterCharacter() public {
        (uint256 roleId, address walletAddr) = _createCharacter(player1);
        assertTrue(walletAddr != address(0), "Wallet not created");

        (bool isValid, uint256 x, uint256 y) = core.getEntityPosition(walletAddr);
        assertFalse(isValid, "Should not be fully valid until VRF resolves");

        vrfMock.fulfillRandomWords(1, address(randomizer));

        (isValid, x, y) = core.getEntityPosition(walletAddr);
        assertTrue(isValid, "Character should be valid after spawn");
    }

    function test_RegisterCharacterWithProfile() public {
        (, address walletAddr) = _createCharacterWithProfile(player1, "alpha123", 1);

        IAgentboxCore.RoleProfileSnapshot memory profile = core.getRoleProfile(walletAddr);
        assertEq(profile.nickname, "alpha123", "Nickname should be stored");
        assertEq(profile.gender, 1, "Gender should be stored");
        assertEq(core.getRoleWalletByNickname("alpha123"), walletAddr, "Nickname lookup should resolve role wallet");
    }

    function test_RegisterCharacterRejectsDuplicateNickname() public {
        _createCharacterWithProfile(player1, "sharedname", 1);

        vm.expectRevert(NicknameAlreadyTaken.selector);
        vm.prank(player2);
        core.createCharacter{value: 0.01 ether}("sharedname", 2);
    }

    function test_RegisterCharacterRejectsInvalidNicknameLength() public {
        vm.expectRevert(InvalidNicknameLength.selector);
        vm.prank(player1);
        core.createCharacter{value: 0.01 ether}("ab", 1);
    }

    function test_Movement() public {
        (, address walletAddr) = _createCharacter(player1);

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
        (, address walletAddr) = _createCharacter(player1);

        vrfMock.fulfillRandomWords(1, address(randomizer));

        (, uint256 startX, uint256 startY) = core.getEntityPosition(walletAddr);
        uint256 expectedX = (startX + 1) % config.mapWidth();

        vm.expectEmit(true, false, false, true);
        emit RoleMoved(walletAddr, expectedX, startY);

        vm.prank(player1);
        core.moveTo(walletAddr, expectedX, startY);

        (, uint256 endX, uint256 endY) = core.getEntityPosition(walletAddr);
        assertEq(endX, expectedX, "X should increment by 1 with wraparound");
        assertEq(endY, startY, "Y should stay the same");
    }

    function test_LandIsERC721Tradable() public {
        (, address wallet1) = _createCharacter(player1);
        (, address wallet2) = _createCharacter(player2);

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

    function test_CancelTeachingAwardsSkillWhenLearningDurationMet() public {
        config.setMapDimensions(100, 100);
        core.setSkillBlocks(1, 2);

        (, address teacherWallet) = _createCharacter(player1);
        (, address studentWallet) = _createCharacter(player2);

        vrfMock.fulfillRandomWords(1, address(randomizer));
        vrfMock.fulfillRandomWords(2, address(randomizer));

        (, uint256 teacherX, uint256 teacherY) = core.getEntityPosition(teacherWallet);

        core.setNPC(1, teacherX, teacherY, 1);

        vm.prank(player1);
        core.startLearning(teacherWallet, 1);

        vm.roll(block.number + 2);

        vm.prank(player1);
        core.finishLearning(teacherWallet);

        vm.startPrank(player2);
        core.startTeleport(studentWallet, teacherX, teacherY);
        vm.stopPrank();

        vm.roll(block.number + 100);

        vm.prank(player2);
        core.finishTeleport(studentWallet);

        vm.prank(player2);
        core.requestLearningFromPlayer(studentWallet, teacherWallet, 1);

        vm.prank(player1);
        core.acceptTeaching(teacherWallet, studentWallet);

        vm.roll(block.number + 4);

        vm.prank(player1);
        core.cancelTeaching(teacherWallet);

        assertTrue(core.getRoleSkill(studentWallet, 1), "student should learn the skill");
        assertEq(core.getRoleSnapshot(studentWallet).state, uint8(0), "student should be idle");
        assertEq(core.getRoleSnapshot(teacherWallet).state, uint8(0), "teacher should be idle");
    }

    function test_DiamondCutRejectsDuplicateSelectorAdds() public {
        AgentboxDiamond diamond = new AgentboxDiamond();
        ActionFacet firstFacet = new ActionFacet();
        ActionFacet secondFacet = new ActionFacet();

        AgentboxDiamond.FacetCut[] memory initialCut = new AgentboxDiamond.FacetCut[](1);
        bytes4[] memory firstSelectors = new bytes4[](1);
        firstSelectors[0] = ActionFacet.moveTo.selector;
        initialCut[0] = AgentboxDiamond.FacetCut({
            facetAddress: address(firstFacet),
            action: AgentboxDiamond.FacetCutAction.Add,
            functionSelectors: firstSelectors
        });
        diamond.diamondCut(initialCut);

        AgentboxDiamond.FacetCut[] memory duplicateCut = new AgentboxDiamond.FacetCut[](1);
        bytes4[] memory duplicateSelectors = new bytes4[](1);
        duplicateSelectors[0] = ActionFacet.moveTo.selector;
        duplicateCut[0] = AgentboxDiamond.FacetCut({
            facetAddress: address(secondFacet),
            action: AgentboxDiamond.FacetCutAction.Add,
            functionSelectors: duplicateSelectors
        });

        vm.expectRevert(bytes("Selector already exists"));
        diamond.diamondCut(duplicateCut);
    }

    function test_GatheringMintsSnapshottedResourceTypeWhenPointIsReconfigured() public {
        config.setMapDimensions(100, 100);
        core.setSkillBlocks(1, 1);

        (, address walletAddr) = _createCharacter(player1);

        vrfMock.fulfillRandomWords(1, address(randomizer));

        (, uint256 x, uint256 y) = core.getEntityPosition(walletAddr);

        core.setNPC(1, x, y, 1);

        vm.prank(player1);
        core.startLearning(walletAddr, 1);

        vm.roll(block.number + 1);

        vm.prank(player1);
        core.finishLearning(walletAddr);

        core.setResourcePoint(x, y, 1, 10);

        vm.prank(player1);
        core.startGather(walletAddr, 2);

        core.setResourcePoint(x, y, 2, 10);

        vm.roll(block.number + 4);

        vm.prank(player1);
        core.finishGather(walletAddr);

        assertEq(resource.balanceOf(walletAddr, 1), 2, "gather should mint the original resource type");
        assertEq(resource.balanceOf(walletAddr, 2), 0, "reconfigured resource type should not be minted");

        IAgentboxCore.RoleActionSnapshot memory action = core.getRoleActionSnapshot(walletAddr);
        assertEq(action.gatheringTargetLandId, y * config.mapWidth() + x, "read snapshot should expose the raw land id");
        assertEq(action.gatheringResourceType, 1, "read snapshot should expose the snapshotted resource type");
    }

    function test_CancelTeachingBeforeLearningDurationMetDoesNotAwardSkill() public {
        config.setMapDimensions(100, 100);
        core.setSkillBlocks(1, 2);

        (, address teacherWallet) = _createCharacter(player1);
        (, address studentWallet) = _createCharacter(player2);

        vrfMock.fulfillRandomWords(1, address(randomizer));
        vrfMock.fulfillRandomWords(2, address(randomizer));

        (, uint256 teacherX, uint256 teacherY) = core.getEntityPosition(teacherWallet);

        core.setNPC(1, teacherX, teacherY, 1);

        vm.prank(player1);
        core.startLearning(teacherWallet, 1);

        vm.roll(block.number + 2);

        vm.prank(player1);
        core.finishLearning(teacherWallet);

        vm.startPrank(player2);
        core.startTeleport(studentWallet, teacherX, teacherY);
        vm.stopPrank();

        vm.roll(block.number + 100);

        vm.prank(player2);
        core.finishTeleport(studentWallet);

        vm.prank(player2);
        core.requestLearningFromPlayer(studentWallet, teacherWallet, 1);

        vm.prank(player1);
        core.acceptTeaching(teacherWallet, studentWallet);

        vm.roll(block.number + 1);

        vm.prank(player1);
        core.cancelTeaching(teacherWallet);

        assertFalse(core.getRoleSkill(studentWallet, 1), "student should not learn the skill");
        assertEq(core.getRoleSnapshot(studentWallet).state, uint8(0), "student should be idle");
        assertEq(core.getRoleSnapshot(teacherWallet).state, uint8(0), "teacher should be idle");
    }

    function test_RetryingSpawnRequestDoesNotLetStaleCallbackRespawnRoleZero() public {
        (, address wallet0) = _createCharacter(player1);

        vrfMock.fulfillRandomWords(1, address(randomizer));
        (, uint256 role0XBefore, uint256 role0YBefore) = core.getEntityPosition(wallet0);

        (, address wallet1) = _createCharacter(player2);

        vm.roll(block.number + 100);
        uint256 retriedRequestId = randomizer.retryRequest(2);
        assertEq(retriedRequestId, 3, "retry should create the next request id");

        // Old request 2 fulfills late. This must be ignored rather than defaulting to Respawn(roleId=0).
        vrfMock.fulfillRandomWords(2, address(randomizer));

        (, uint256 role0XAfterStale, uint256 role0YAfterStale) = core.getEntityPosition(wallet0);
        assertEq(role0XAfterStale, role0XBefore, "stale callback should not move role 0");
        assertEq(role0YAfterStale, role0YBefore, "stale callback should not move role 0");

        (bool role1ValidBeforeRetryFulfill,,) = core.getEntityPosition(wallet1);
        assertFalse(role1ValidBeforeRetryFulfill, "role 1 should still be pending until the retried request fulfills");

        vrfMock.fulfillRandomWords(retriedRequestId, address(randomizer));

        (bool role1ValidAfterRetryFulfill,,) = core.getEntityPosition(wallet1);
        assertTrue(role1ValidAfterRetryFulfill, "role 1 should spawn from the retried request");
    }

    function test_SetMapDimensionsRejectsZeroValues() public {
        vm.expectRevert(InvalidMapDimensions.selector);
        config.setMapDimensions(0, 100);

        vm.expectRevert(InvalidMapDimensions.selector);
        config.setMapDimensions(100, 0);
    }

    function test_SetResourcePointRejectsOutOfBoundsCoordinates() public {
        uint256 mapWidth = config.mapWidth();
        uint256 mapHeight = config.mapHeight();

        vm.expectRevert(TargetOutOfBounds.selector);
        core.setResourcePoint(mapWidth, 0, 1, 10);

        vm.expectRevert(TargetOutOfBounds.selector);
        core.setResourcePoint(0, mapHeight, 1, 10);
    }

    function test_SetNPCRejectsOutOfBoundsCoordinates() public {
        uint256 mapWidth = config.mapWidth();
        uint256 mapHeight = config.mapHeight();

        vm.expectRevert(TargetOutOfBounds.selector);
        core.setNPC(1, mapWidth, 0, 1);

        vm.expectRevert(TargetOutOfBounds.selector);
        core.setNPC(1, 0, mapHeight, 1);
    }

    function test_AdminSettersRejectValuesThatOverflowStorageTypes() public {
        vm.expectRevert(ValueOutOfRange.selector);
        core.setResourcePoint(0, 0, uint256(type(uint64).max) + 1, 10);

        vm.expectRevert(ValueOutOfRange.selector);
        core.setResourcePoint(0, 0, 1, uint256(type(uint64).max) + 1);

        vm.expectRevert(ValueOutOfRange.selector);
        core.setNPC(1, 0, 0, uint256(type(uint32).max) + 1);

        vm.expectRevert(ValueOutOfRange.selector);
        core.setRecipe(1, new uint256[](0), new uint256[](0), 1, uint256(type(uint64).max) + 1, 1001);

        vm.expectRevert(ValueOutOfRange.selector);
        core.setEquipmentConfig(1001, 1, int256(type(int32).max) + 1, 0, 0, 0, 0);
    }

    function test_TriggerMintUsesConfiguredMintAmount() public {
        config.setMapDimensions(10, 10);
        uint256 mintAmount = 77 * 10 ** 18;
        config.setMintAmount(mintAmount);

        vm.roll(block.number + config.mintIntervalBlocks());
        economy.triggerMint();
        vrfMock.fulfillRandomWords(1, address(economy));

        uint256 totalGroundTokens = 0;
        for (uint256 landId = 0; landId < config.mapWidth() * config.mapHeight(); landId++) {
            uint256 amount = economy.groundTokens(landId);
            if (amount > 0) {
                totalGroundTokens += amount;
            }
        }

        assertEq(totalGroundTokens, mintAmount, "ground drop should use config.mintAmount");
    }

    function test_TriggerMintRespectsConfiguredMaxMintCount() public {
        config.setMaxMintCount(1);

        vm.roll(block.number + config.mintIntervalBlocks());
        economy.triggerMint();
        vrfMock.fulfillRandomWords(1, address(economy));
        assertEq(economy.mintsCount(), 1, "first mint should succeed");

        vm.roll(block.number + config.mintIntervalBlocks());
        vm.expectRevert(MaxMintCountReached.selector);
        economy.triggerMint();
    }

    function _createCharacter(address player) internal returns (uint256 roleId, address walletAddr) {
        roleId = roleToken.totalMinted();
        vm.prank(player);
        core.createCharacter{value: 0.01 ether}();
        walletAddr = roleToken.wallets(roleId);
    }

    function _createCharacterWithProfile(address player, string memory nickname, uint8 gender)
        internal
        returns (uint256 roleId, address walletAddr)
    {
        roleId = roleToken.totalMinted();
        vm.prank(player);
        core.createCharacter{value: 0.01 ether}(nickname, gender);
        walletAddr = roleToken.wallets(roleId);
    }
}
