//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import{Script,console} from 'forge-std/Script.sol';
import {HelperConfig, CodeConstants} from './HelperConfig.s.sol';
import{VRFCoordinatorV2_5Mock} from '@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol';
import {LinkToken} from 'test/mocks/LinkToken.sol';
import {DevOpsTools} from 'lib/foundry-devops/src/DevOpsTools.sol';
 contract CreateSubscription is Script, CodeConstants{
    function createSubscriptionUsingConfig() private returns(uint256,address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator =  helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId,) = createSubscription(vrfCoordinator,account);
        return (subId,vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator , address account) public returns(uint256,address) {
       console.log('creating subscription',block.chainid);
       vm.startBroadcast(account);
       uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
       vm.stopBroadcast();

       console.log('your subscription id is',subId);
       console.log('update your subscription id');
       return (subId,vrfCoordinator);
        }
    function run() public {
           createSubscriptionUsingConfig();
    }

 }


contract FundSubscription is Script{


    uint256 public constant FUND_AMOUNT = 200000000000 ether;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    


    function fundSubscriptionUsingConfig() public {
        HelperConfig  helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscription;
        address linkToken = helperConfig.getConfig().link;
        address account  = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator,subscriptionId,linkToken,account);
    }
function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account) public {
       console.log('vrf coordinator address',vrfCoordinator);
       console.log('subscription id',subscriptionId);
       console.log('block chain id',block.chainid);
       if (block.chainid == LOCAL_CHAIN_ID){
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId,FUND_AMOUNT);
        vm.stopBroadcast();

       } else{
        vm.startBroadcast(account);
        LinkToken(linkToken).transferAndCall(vrfCoordinator,FUND_AMOUNT,abi.encode(subscriptionId));
        vm.stopBroadcast();
       }

    }

    function run() public{
        fundSubscriptionUsingConfig();
    }
    
}

contract AddConsumer is Script{


 function addConsumerUsingConfig(address MostrecentlyDeployed) public{
 HelperConfig helperConfig = new HelperConfig();
 address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
 uint256 subscriptionId = helperConfig.getConfig().subscription;
 address account = helperConfig.getConfig().account;
 addConsumer(MostrecentlyDeployed,vrfCoordinator,subscriptionId,account);

 }

 function addConsumer( address consumerToAddtoVrf, address vrfCoordinator, uint256 subscriptionId,address account ) public{
   console.log('consumer address',consumerToAddtoVrf);
   console.log('vrf coordinator address',vrfCoordinator);
   console.log('chain id', block.chainid);
   vm.startBroadcast(account);
   VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId,consumerToAddtoVrf);
   vm.stopBroadcast();
 }

function run() external{
     address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment('Raffle',block.chainid);
     addConsumerUsingConfig(mostRecentlyDeployed);
 }

}
