// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Errors.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "./interfaces/IAgentboxCore.sol";

contract AgentboxRandomizer is VRFConsumerBaseV2Plus {
    IVRFCoordinatorV2Plus public COORDINATOR;
    uint256 public s_subscriptionId;
    bytes32 public s_keyHash;
    uint32 public callbackGasLimit = 500000;
    uint16 public requestConfirmations = 3;

    address public gameCore;

    enum RequestType {
        Respawn,
        NPCRefresh,
        Spawn
    }

    enum RequestStatus {
        None,
        Pending,
        Retried
    }

    struct RequestInfo {
        RequestType reqType;
        uint256 targetId;
        uint256 requestBlock;
        RequestStatus status;
    }

    mapping(uint256 => RequestInfo) public requests;
    event GameCoreSet(address indexed gameCore);
    event RandomRequestCreated(uint256 indexed requestId, uint8 indexed requestType, uint256 indexed targetId, uint256 requestBlock);
    event RandomRequestRetried(
        uint256 indexed oldRequestId,
        uint256 indexed newRequestId,
        uint8 requestType,
        uint256 targetId,
        uint256 requestBlock
    );
    event RandomRequestFulfilled(uint256 indexed requestId, uint8 requestType, uint256 targetId, uint256 randomWord);
    event RandomRequestIgnored(uint256 indexed requestId, uint8 requestType, uint256 targetId, uint8 status);

    constructor(address vrfCoordinator, bytes32 keyHash, uint256 subscriptionId)
        VRFConsumerBaseV2Plus(vrfCoordinator)
    {
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
    }

    function setGameCore(address _core) external onlyOwner {
        gameCore = _core;
        emit GameCoreSet(_core);
    }

    modifier onlyCore() {
        if (!(msg.sender == gameCore)) revert OnlyGameCore();
        _;
    }

    function requestRespawn(uint256 roleId) external onlyCore returns (uint256 requestId) {
        requestId = _createRequest(RequestType.Respawn, roleId);
    }

    function requestSpawn(uint256 roleId) external onlyCore returns (uint256 requestId) {
        requestId = _createRequest(RequestType.Spawn, roleId);
    }

    function requestNPCRefresh(uint256 npcId) external onlyCore returns (uint256 requestId) {
        requestId = _createRequest(RequestType.NPCRefresh, npcId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        RequestInfo memory req = requests[requestId];
        if (req.status != RequestStatus.Pending) {
            if (req.status != RequestStatus.None) {
                emit RandomRequestIgnored(requestId, uint8(req.reqType), req.targetId, uint8(req.status));
                delete requests[requestId];
            }
            return;
        }

        if (req.reqType == RequestType.Respawn) {
            IAgentboxCore(gameCore).processRespawn(req.targetId, randomWords[0]);
        } else if (req.reqType == RequestType.NPCRefresh) {
            IAgentboxCore(gameCore).processNPCRefresh(req.targetId, randomWords[0]);
        } else if (req.reqType == RequestType.Spawn) {
            IAgentboxCore(gameCore).processSpawn(req.targetId, randomWords[0]);
        }

        emit RandomRequestFulfilled(requestId, uint8(req.reqType), req.targetId, randomWords[0]);

        delete requests[requestId];
    }

    function retryRequest(uint256 oldRequestId) external returns (uint256 newRequestId) {
        RequestInfo storage oldRequest = requests[oldRequestId];
        if (!(oldRequest.requestBlock > 0)) revert RequestDoesNotExist();
        if (!(oldRequest.status == RequestStatus.Pending)) revert RequestDoesNotExist();
        if (!(block.number >= oldRequest.requestBlock + 100)) revert TooEarlyToRetry();

        RequestInfo memory req = oldRequest;
        oldRequest.status = RequestStatus.Retried;
        newRequestId = _createRequest(req.reqType, req.targetId);
        emit RandomRequestRetried(oldRequestId, newRequestId, uint8(req.reqType), req.targetId, block.number);
    }

    function _createRequest(RequestType reqType, uint256 targetId) internal returns (uint256 requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        requests[requestId] =
            RequestInfo({reqType: reqType, targetId: targetId, requestBlock: block.number, status: RequestStatus.Pending});
        emit RandomRequestCreated(requestId, uint8(reqType), targetId, block.number);
    }
}
