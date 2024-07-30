// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployRaffle} from '../../script/DeployRaffle.s.sol';
import {Test,console} from 'forge-std/Test.sol';
import {Raffle} from '../../src/Raffle.sol';
import {HelperConfig} from '../../script/HelperConfig.s.sol';
import{Vm} from 'forge-std/Vm.sol';
import{VRFCoordinatorV2_5Mock} from '@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol';
import {CodeConstants} from '../../script/HelperConfig.s.sol';
contract RaffleTest is Test,CodeConstants {
    HelperConfig public helperConfig;
    Raffle public raffle;

    address public PLAYER = makeAddr('player');
    uint256 public constant STARTING_BALANCE = 50 ether;
    uint256 public constant ENTRANCEFEE = 2 ether;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscription;
    uint32 callbackGasLimit;

    event RaffleEntered(address indexed player);
    event winnerPicked(address indexed winner);
    

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscription = config.subscription;
        callbackGasLimit = config.callbackGasLimit;
        vm.deal(PLAYER, STARTING_BALANCE);
    }

    function testRaffleStateIsOpen() public view {
        Raffle.raffleState raffleState = raffle.getRaffleState();
        assert( raffleState == Raffle.raffleState.OPEN);
    }

    function testRafflewithoutAnyFund() public {
        vm.prank(PLAYER);
        vm.expectRevert();
        raffle.enterRaffle{value: 0}();
    }

    function testPlayerCanEnterRaffle() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCEFEE}();
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEmitEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: ENTRANCEFEE}();
    }

    function testRaffleNotOpenWhenCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCEFEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1); // Roll to the next block to simulate time passage

        raffle.performUpkeep('');
        
        vm.expectRevert();
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCEFEE}();
    }

    /*/////////////////////////////////////////////////////
                    checkUpkeep                            
    //////////////////////////////////////////////////////*/

    function testCheckUpKeepReturnFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1); // Roll to the next block to simulate time passage
        
        (bool upKeepNeeded, ) = raffle.checkUpkeep('');
        
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnFalseIfRaffleIsNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCEFEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1); // Roll to the next block to simulate time passage
         Raffle.raffleState rstate = raffle.getRaffleState();
        console.log(uint256(rstate));
        raffle.performUpkeep('');

        (bool upKeepNeeded, ) = raffle.checkUpkeep('');

        assert(upKeepNeeded == false);
    }

    /*/////////////////////////////////////////////////////
                    PERFORM UPKEEP   
    //////////////////////////////////////////////////////*/

    function testCheckUpKeepReturnTrueIfRaffleIsOpen() public{
       

       vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCEFEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1); // Roll to the next block to simulate time passage
        Raffle.raffleState rstate = raffle.getRaffleState();
        console.log(uint256(rstate));
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded == true);
    }
function testPerformUpkeepRevertIfUpkeepIsFalse() public{
    //Arrange
 uint256 currentBalance = 0;
 uint256 playerLength = 0;
 Raffle.raffleState rstate = raffle.getRaffleState();

 // Act

 vm.prank(PLAYER);
 raffle.enterRaffle{value:ENTRANCEFEE}();
 currentBalance += ENTRANCEFEE;
 playerLength = 1;

 vm.expectRevert(
    abi.encodeWithSelector(Raffle.raffleConditionMustBeTrue.selector, currentBalance, playerLength,rstate)
 );
 raffle.performUpkeep('');
}


modifier RaffleRunning{
   vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCEFEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
}


function testPerformUpKeepUpdateAndEmitRequestId() public RaffleRunning{
         

        vm.recordLogs();
        raffle.performUpkeep('');
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];
        Raffle.raffleState rstate = raffle.getRaffleState();
        console.log(uint256(requestId));
        assert(uint256(requestId) > 0);
        assert(uint256(rstate) == 1);

}
    /*//////////////////////////////////////////////////////
                  FULFILL RANDOM WORDS
    ///////////////////////////////////////////////////////*/


    function testFulfilRandomWordsCanOnlyPassedAfterCallingPerformUpKeep(uint256 randomRequest)public RaffleRunning{
         vm.expectRevert();
         VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequest,address(raffle));

    }


    modifier skipFork{

        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCEFEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        if(block.chainid != LOCAL_CHAIN_ID){
            return;
        }
        _;
    }

    function testFulfilRandomWordsPickWinnerResetAndSendMoney() public skipFork{
 
       uint256 additionalEntrants = 3; //4 player in the raffle
       uint256 startingIndex = 1;
       address expectedWinner = address(1);

       for( uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++){
                  address newPlayers = address(uint160(i));
                  hoax(newPlayers, 2 ether);
                   raffle.enterRaffle{value: entranceFee}();          
       }
       uint256 StartTime = raffle.getLastTimeStamp();
       uint256 winnerBalance = expectedWinner.balance;
       vm.recordLogs();
        raffle.performUpkeep('');
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId),address(raffle));

        address recentWinner = raffle.getRecentWinner();
        Raffle.raffleState raffleState = raffle.getRaffleState();
        uint256 getWinnerBalance = recentWinner.balance;
        uint256 endingTime = raffle.getLastTimeStamp();
        uint256 prize = entranceFee *(additionalEntrants + 1);
        

        console.log("get winner's balance :",getWinnerBalance );
        console.log("expected winner's balance", winnerBalance + prize);

        assert(expectedWinner == recentWinner);
        assert(uint256(raffleState) == 0);
       // assert(getWinnerBalance == winnerBalance + prize);
        assert(endingTime > StartTime);
        
    }






}