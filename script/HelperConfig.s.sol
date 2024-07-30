//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import {LinkToken} from 'test/mocks/LinkToken.sol';
import {Script} from 'forge-std/Script.sol';
import{VRFCoordinatorV2_5Mock} from '@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol';



abstract contract CodeConstants{
uint96 public constant MOCK_BASE_FEE = 0.25 ether ;
int256 public constant MOCK_WEI_PER_UNIT_LINK = 1e9;
uint96 public constant MOCK_GASPRICE= 4e15;
uint256 public constant SEPOLIA_ETH_CHAINID =11155111;
uint256 public constant LOCAL_CHAIN_ID = 31337;
}
contract HelperConfig is Script,CodeConstants{
   error HelperConfig_invalid();

    struct NetworkConfig{
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator; 
    bytes32 gasLane;
    uint256 subscription ; 
    uint32 callbackGasLimit;
    address link;
    address account;
    }

    NetworkConfig public localNetwork;
    mapping(uint256 => NetworkConfig)  public networkConfig;

    constructor(){
        networkConfig[SEPOLIA_ETH_CHAINID] = getSepoliaConfig();
}

function getConfigBYChainid (uint256 chainid) public returns (NetworkConfig memory){
        if(networkConfig[chainid].vrfCoordinator != address(0)){
            return networkConfig[chainid];
        }
        else if(chainid == LOCAL_CHAIN_ID){
            return  getOrCreateAnvilConfig();
        }
        else{
            revert HelperConfig_invalid();
        }
    }
    function getConfig() public returns(NetworkConfig memory){
        return getConfigBYChainid(block.chainid);
    }

    function getSepoliaConfig() public pure returns(NetworkConfig memory){
        return NetworkConfig({
            entranceFee:0.1 ether,
            interval : 30, //30 secs
            vrfCoordinator:0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane:0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscription:114034964678058928785110738321013154482008529442115846326277962884422825823445,
            callbackGasLimit:500000,
            link:0x779877A7B0D9E8603169DdbD7836e478b4624789, 
            account:0x96017f6A69c0846Ef83D7669abb65F7Da4a422f3
        });
    }

    
    function getOrCreateAnvilConfig() public returns(NetworkConfig memory){
        if(localNetwork.vrfCoordinator != address(0)){
            return localNetwork;
        }
        else{
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock mockVrfCoordinator = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GASPRICE, MOCK_WEI_PER_UNIT_LINK);
            LinkToken linkToken = new LinkToken();
            vm.stopBroadcast();

            localNetwork = NetworkConfig({
            entranceFee:0.1 ether,
            interval : 30, //30 secs
            vrfCoordinator:address(mockVrfCoordinator),
            gasLane:0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscription:0,
            callbackGasLimit:500000,
            link:address(linkToken),
            account:0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
            });

        return localNetwork;
        }
    }

}