// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std-1.9.7/src/Script.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {InfraredVaultHandlerHelperConfig} from "@script/handlers/infrared/InfraredVaultHandlerHelperConfig.sol";
import {PositionsInfraredVaultHandler} from "@src/handlers/infrared/PositionsInfraredVaultHandler.sol";

contract DeployPositionsInfraredVaultHandler is Script {
    function run() public returns (InfraredVaultHandlerHelperConfig, PositionsInfraredVaultHandler) {
        InfraredVaultHandlerHelperConfig helperConfig = new InfraredVaultHandlerHelperConfig();
        InfraredVaultHandlerHelperConfig.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        vm.startBroadcast();

        address proxy = Upgrades.deployUUPSProxy(
            "PositionsInfraredVaultHandler.sol",
            abi.encodeCall(
                PositionsInfraredVaultHandler.initialize,
                (
                    networkConfig.admin,
                    networkConfig.upgrader,
                    networkConfig.entryPoint,
                    networkConfig.relayer,
                    networkConfig.oracle
                )
            ),
            opts
        );

        vm.stopBroadcast();

        return (helperConfig, PositionsInfraredVaultHandler(payable(proxy)));
    }
}
