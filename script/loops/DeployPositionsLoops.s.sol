// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std-1.9.7/src/Script.sol";
import {PositionsLoopsHelperConfig} from "./PositionsLoopsHelperConfig.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades-0.4.0/src/Upgrades.sol";
import {PositionsLoops} from "@src/protocols/loops/PositionsLoops.sol";
import {Options} from "openzeppelin-foundry-upgrades-0.4.0/src/Options.sol";

contract DeployPositionsLoops is Script {
    PositionsLoopsHelperConfig helperConfig;

    function run() public returns (PositionsLoopsHelperConfig, PositionsLoops) {
        helperConfig = new PositionsLoopsHelperConfig();
        PositionsLoopsHelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        vm.startBroadcast();

        address proxy = Upgrades.deployUUPSProxy(
            "PositionsLoops.sol",
            abi.encodeCall(
                PositionsLoops.initialize,
                (
                    config.admin,
                    config.positionsRelayer,
                    config.lendingPool,
                    config.islandRouter,
                    config.island,
                    config.swapRouter,
                    config.vault,
                    config.bgt
                )
            ),
            opts
        );

        vm.stopBroadcast();

        return (helperConfig, PositionsLoops(payable(proxy)));
    }
}
