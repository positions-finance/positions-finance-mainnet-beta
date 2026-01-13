// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {PositionsClient} from "@test/mock/PositionsClient.m.sol";
import {HelperConfigClient, NetworkConfigClient} from "./HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployMockClient is Script {
    HelperConfigClient helperConfig;

    function run() public returns (HelperConfigClient, PositionsClient) {
        helperConfig = new HelperConfigClient();
        NetworkConfigClient memory config = helperConfig.getActiveNetworkConfig();

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        vm.startBroadcast();

        address proxy = Upgrades.deployUUPSProxy(
            "PositionsClient.m.sol",
            abi.encodeCall(PositionsClient.__PositionsClient_init, (config.admin, config.relayer)),
            opts
        );

        vm.stopBroadcast();

        return (helperConfig, PositionsClient(proxy));
    }
}
