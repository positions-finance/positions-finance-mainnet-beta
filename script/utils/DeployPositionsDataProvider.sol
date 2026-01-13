// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

import {PositionsDataProviderHelperConfig} from "./PositionsDataProviderHelperConfig.sol";
import {PositionsDataProvider} from "@src/utils/PositionsDataProvider.sol";

contract DeployPositionsDataProvider is Script {
    PositionsDataProviderHelperConfig public helperConfig;
    PositionsDataProvider public dataProvider;

    /// @notice Deploy with addresses passed as parameters (recommended for mainnet)
    /// @param entrypoint The PositionsVaultsEntrypoint proxy address
    /// @param lendingPool The PositionsLendingPool proxy address
    function run(address entrypoint, address lendingPool) public returns (PositionsDataProvider) {
        require(entrypoint != address(0), "Entrypoint address cannot be zero");
        require(lendingPool != address(0), "LendingPool address cannot be zero");

        vm.startBroadcast();
        dataProvider = new PositionsDataProvider(entrypoint, lendingPool);
        vm.stopBroadcast();

        return dataProvider;
    }

    /// @notice Deploy using addresses from config (if pre-configured)
    function run() public returns (PositionsDataProvider) {
        helperConfig = new PositionsDataProviderHelperConfig();
        PositionsDataProviderHelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        require(config.entrypoint != address(0), "Entrypoint not configured - use run(entrypoint, lendingPool) instead");
        require(config.lendingPool != address(0), "LendingPool not configured - use run(entrypoint, lendingPool) instead");

        return run(config.entrypoint, config.lendingPool);
    }
}
