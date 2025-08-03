//SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    error Raffle__SendMoreEthToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 Balance, uint256 playerslength, uint256 raffleState);

    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1

    }

    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entrancefee;
    uint256 private immutable i_interval;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    bytes32 private immutable i_keyHash;
    uint256 private s_lastTimeStamp;
    address private s_recentwinner;
    RaffleState private s_rafflestate; //start as open

    event EnterRaffle(address indexed player);
    event Winnerpicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entrancefee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entrancefee = entrancefee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_rafflestate = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value != i_entrancefee) {
            revert Raffle__SendMoreEthToEnterRaffle();
        }

        if (s_rafflestate != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnterRaffle(msg.sender);
    }

    function checkupkeep(bytes memory) public view returns (bool upkeepneeded, bytes memory) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool IsOpen = (s_rafflestate == RaffleState.OPEN);
        bool hasBalance = (address(this).balance > 0);
        bool hasPlayers = (s_players.length > 0);
        upkeepneeded = (timeHasPassed && IsOpen && hasBalance && hasPlayers);
        return (upkeepneeded, "");
    }

    function performUpkeep() external {
        (bool upkeepneeded,) = checkupkeep("");
        if (!upkeepneeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_rafflestate));
        }
        s_rafflestate = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerIndex];

        s_rafflestate = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_recentwinner = recentWinner;
        s_lastTimeStamp = block.timestamp;
        emit Winnerpicked(recentWinner);

        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    function getEntrancefee() public view returns (uint256) {
        return i_entrancefee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_rafflestate;
    }

    function getPlayers(uint256 indexofplayer) external view returns (address) {
        return s_players[indexofplayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentwinner;
    }
}
