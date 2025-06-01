// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {PositionsRelayer} from "@src/poc/PositionsRelayer.sol";
import {HelperConfig, NetworkConfig} from "./HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployRelayer is Script {
    HelperConfig helperConfig;

    function run() public returns (HelperConfig, PositionsRelayer) {
        helperConfig = new HelperConfig();
        NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        vm.startBroadcast();

        address proxy = Upgrades.deployUUPSProxy(
            "PositionsRelayer.sol",
            abi.encodeCall(
                PositionsRelayer.__PositionsRelayer_init, (config.admin, config.feeReceipient, config.feePercentage)
            ),
            opts
        );

        vm.stopBroadcast();

        return (helperConfig, PositionsRelayer(proxy));
    }
}

contract UpgradeRelayer is Script {
    HelperConfig helperConfig;

    function run() public returns (HelperConfig, PositionsRelayer) {
        helperConfig = new HelperConfig();

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        address proxy = 0x7B8fcfDA1541A80FD64887261CC2Db83648F1ECF;

        vm.startBroadcast();

        // Upgrades.upgradeProxy(proxy, "PositionsRelayer.sol", "", opts);
        PositionsRelayer(proxy).grantRole(
            PositionsRelayer(proxy).RELAYER_ROLE(), 0x7233Db9c06D301a8C12f1738aAF722bBB32a0A5E
        );

        vm.stopBroadcast();

        return (helperConfig, PositionsRelayer(proxy));
    }
}
