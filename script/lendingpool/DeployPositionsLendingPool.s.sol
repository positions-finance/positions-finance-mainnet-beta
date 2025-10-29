// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

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

        // address proxy = Upgrades.deployUUPSProxy(
        //     "PositionsLendingPool.sol",
        //     abi.encodeCall(
        //         PositionsLendingPool.initialize,
        //         (config.admin, config.positionsRelayer, config.oracle, config.initialReserveFactor)
        //     ),
        //     opts
        // );
        // PositionsLendingPool(0x501eB689C59c9B577896bcAbcC92bf6926d0B968).utilization(3);

        // for (uint256 i; i < config.assets.length; ++i) {
        PositionsLendingPool(0x501eB689C59c9B577896bcAbcC92bf6926d0B968).createLendingPool(
            0xDeadf18CB9233770FE8874c78D7483b4A126B34a,
            // placeholder irm
            PositionsLendingPool.InterestRateModel({
                baseRate: 0,
                slope1: 675000000000000000000000000,
                slope2: 750000000000000000000000000,
                optimalUtilization: 750000000000000000000000000
            })
        );
        // }

        vm.stopBroadcast();

        // return (helperConfig, PositionsLendingPool(proxy));
    }
}

contract UpgradePositionsLendingPool is Script {
    HelperConfigLendingPool helperConfig;

    function run() public returns (HelperConfigLendingPool, PositionsLendingPool) {
        helperConfig = new HelperConfigLendingPool();

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        address proxy = 0x501eB689C59c9B577896bcAbcC92bf6926d0B968;

        vm.startBroadcast();

        Upgrades.upgradeProxy(proxy, "PositionsLendingPool.sol", "", opts);

        vm.stopBroadcast();

        return (helperConfig, PositionsLendingPool(proxy));
    }
}
