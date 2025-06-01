// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

import {PositionsDataProviderHelperConfig} from "./PositionsDataProviderHelperConfig.sol";
import {PositionsDataProvider} from "@src/utils/PositionsDataProvider.sol";

contract DeployPositionsDataProvider is Script {
    PositionsDataProviderHelperConfig public helperConfig;
    PositionsDataProvider public dataProvider;

    function run() public returns (PositionsDataProvider) {
        helperConfig = new PositionsDataProviderHelperConfig();
        PositionsDataProviderHelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        vm.startBroadcast();
        dataProvider = new PositionsDataProvider(config.entrypoint, config.lendingPool);
        vm.stopBroadcast();

        return (dataProvider);
    }
}
