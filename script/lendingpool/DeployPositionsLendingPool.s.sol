// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {PositionsRelayer} from "@src/poc/PositionsRelayer.sol";
import {HelperConfigLendingPool, NetworkConfig} from "./HelperConfig.s.sol";
import {PositionsLendingPool} from "@src/protocols/lendingPool/PositionsLendingPool.sol";
import {Script} from "forge-std/Script.sol";

import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployPositionsLendingPool is Script {
    HelperConfigLendingPool helperConfig;

    function run() public returns (HelperConfigLendingPool, PositionsLendingPool) {
        helperConfig = new HelperConfigLendingPool();
        NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        vm.startBroadcast();

        address proxy = Upgrades.deployUUPSProxy(
            "PositionsLendingPool.sol",
            abi.encodeCall(
                PositionsLendingPool.initialize,
                (config.admin, config.positionsRelayer, config.oracle, config.initialReserveFactor)
            ),
            opts
        );

        for (uint256 i; i < config.assets.length; ++i) {
            PositionsLendingPool(proxy).createLendingPool(
                config.assets[i],
                // placeholder irm
                PositionsLendingPool.InterestRateModel({
                    baseRate: 2e25,
                    slope1: 5e25,
                    slope2: 4e26,
                    optimalUtilization: 9e26
                })
            );
        }

        vm.stopBroadcast();

        return (helperConfig, PositionsLendingPool(proxy));
    }
}

contract UpgradePositionsLendingPool is Script {
    HelperConfigLendingPool helperConfig;

    function run() public returns (HelperConfigLendingPool, PositionsLendingPool) {
        helperConfig = new HelperConfigLendingPool();

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        address proxy = 0x95454df4240cc7Eb1Aa2fc270241E4372114f71C;

        vm.startBroadcast();

        Upgrades.upgradeProxy(proxy, "PositionsLendingPool.sol", "", opts);

        vm.stopBroadcast();

        return (helperConfig, PositionsLendingPool(proxy));
    }
}
