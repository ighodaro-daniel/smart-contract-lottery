//SPDX-License-Identifier: MIT
pragma solidity^0.8.19;


/**
 * @title  A raffle contract
 * @author daniel
 * @notice this contract is for creating a sample raffle
 */
/**
 * Contract elements should be laid out in the following order:
Pragma statements
Import statements
Errors
Libraries,interface and contract
Types Declaration
State Variables
Events
modifiers
function


*Layout of function:
contructors
recieve()
fallback()
external
public
internal
private
views and pure functions
*/

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
//import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
//custom errors


contract Raffle is VRFConsumerBaseV2Plus,AutomationCompatibleInterface{
   //using Math for uint256;
error not_enough();
error transferFailed();
error RaffleNotOpen();
error raffleConditionMustBeTrue(uint256 balance,uint256 players,uint256 s_raffleState);
// using enum to manage state 
enum raffleState {OPEN,CALCULATING}

uint256 private immutable i_entranceFee;
address payable [] private s_players;

//@dev time set for the lottery to elapsed
uint256 private immutable i_interval;
uint256 private s_lastTimeStamp;
bytes32 private immutable i_keyHash;
uint256 private immutable i_subscriptionId;
uint16 private constant REQUEST_CONFIRMATIONS = 3;
uint32 private constant NUMWORDS = 1;
uint32 private immutable i_callBackGasLimit;
address private s_recentWinner;


raffleState private s_raffleState;


/**
 * design pattern
 * check,expression,interact*/

event RaffleEntered(address indexed player);
event winnerPicked(address indexed winner);
event requestRafffleWinner(uint256 indexed requestId);
constructor(
    uint256 entranceFee,
    uint256 interval,
    address vrfCoodinator, 
    bytes32 gasLane,
    uint256 subscription , 
    uint32 callbackGasLimit 

     )
  VRFConsumerBaseV2Plus(vrfCoodinator){
    i_keyHash = gasLane;
    i_entranceFee = entranceFee;
    i_interval = interval;
    s_lastTimeStamp = block.timestamp;
    i_subscriptionId = subscription;
    i_callBackGasLimit = callbackGasLimit;
    s_raffleState = raffleState.OPEN;
    
}

function enterRaffle() public payable{
    //check
    if (msg.value < i_entranceFee){
        revert not_enough();
    }
    if (s_raffleState != raffleState.OPEN){
          revert RaffleNotOpen();
    }
    s_players.push(payable(msg.sender));

    emit RaffleEntered(msg.sender);
    
    }
    /**
     * @dev the checkupkeep function with check if the lottery is ready to pick a winner
     * the following should be true in order for upkeepNeeded to be true:
     * the time interval has passed for the raffle draw
     * the lottery is open
     * the contract should have ETH
     * Implicitly, your subscription has LINK
     * @param -IGNORED 
     * @return upkeepNeeded - return true if it is time to restart the lottery
     * @return 
     */
    function checkUpkeep(bytes memory /* checkData */)
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool hasPassedTime = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool lotteryIsOpened = s_raffleState == raffleState.OPEN;
        bool contractHasEth = address(this).balance > 0;
        bool hasParticipant = s_players.length > 0;

        upkeepNeeded = hasPassedTime&&lotteryIsOpened&&contractHasEth&&hasParticipant;
        return(upkeepNeeded,'');
        
    }

function performUpkeep(bytes calldata /* performData */) external{
    //check
    ( bool upkeepNeeded,) = checkUpkeep('');
   if(!upkeepNeeded){
        revert raffleConditionMustBeTrue(address(this).balance,s_players.length,uint256(s_raffleState));
   }
    s_raffleState = raffleState.CALCULATING;
    VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
              callbackGasLimit: i_callBackGasLimit,
                numWords: NUMWORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            }
            );
     uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
     emit requestRafffleWinner(requestId);
}


 function fulfillRandomWords(uint256 /**requestId*/, uint256[] calldata randomWords) internal override {

    uint256 indexOfWinner = randomWords[0] % s_players.length;
    address payable recentWinner = s_players[indexOfWinner];
    s_recentWinner = recentWinner;
     s_raffleState = raffleState.OPEN;
     s_players = new address payable [](0);
     s_lastTimeStamp = block.timestamp;

    (bool success,) = recentWinner.call{value: address(this).balance}("");
   
    if (!success){
        revert transferFailed();
    }
    emit winnerPicked(s_recentWinner);
 }


//getter for entrance fee

function getEntranceFee() external view returns(uint256){

    return i_entranceFee;
}

 function getRaffleState() public view returns(raffleState){
    return s_raffleState;
 }

 function getPlayer(uint256 _num) external  view returns(address){
    return s_players[_num];
 
} 

function getLastTimeStamp()external view returns(uint256){
    return s_lastTimeStamp;
}


function getRecentWinner() external view returns (address){
    return s_recentWinner;
}
}