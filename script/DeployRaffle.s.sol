//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interaction.s.sol";

contract DeployRaffle is Script {
    function run() public {
        deployRaffle();
    }

    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscription == 0) {
            // if there is no subscription create a new subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscription, config.vrfCoordinator) = createSubscription
                .createSubscription(config.vrfCoordinator,config.account);
            // fund it

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator,
                config.subscription,
                config.link,
                config.account
            );
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscription,
            config.callbackGasLimit);
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            config.vrfCoordinator,
            config.subscription,
            config.account
        );

        return (raffle, helperConfig);
    }
}
