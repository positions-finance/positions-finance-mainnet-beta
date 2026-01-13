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

    /// @notice Deploy with oracle address passed as parameter (recommended for mainnet)
    /// @param oracle The PriceOracle proxy address
    function run(address oracle) public returns (HelperConfigLendingPool, PositionsLendingPool) {
        helperConfig = new HelperConfigLendingPool();
        NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        require(oracle != address(0), "Oracle address cannot be zero");

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        vm.startBroadcast();

        address proxy = Upgrades.deployUUPSProxy(
            "PositionsLendingPool.sol",
            abi.encodeCall(
                PositionsLendingPool.initialize,
                (config.admin, config.positionsRelayer, oracle, config.initialReserveFactor)
            ),
            opts
        );

        vm.stopBroadcast();

        return (helperConfig, PositionsLendingPool(proxy));
    }

    /// @notice Deploy using oracle address from config (if pre-configured)
    function run() public returns (HelperConfigLendingPool, PositionsLendingPool) {
        helperConfig = new HelperConfigLendingPool();
        NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        require(config.oracle != address(0), "Oracle not configured - use run(oracle) instead");

        return run(config.oracle);
    }
}

contract UpgradePositionsLendingPool is Script {
    /// @notice Upgrade an existing LendingPool proxy
    /// @param proxyAddress The existing proxy address to upgrade
    function run(address proxyAddress) public returns (PositionsLendingPool) {
        require(proxyAddress != address(0), "Proxy address cannot be zero");

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        vm.startBroadcast();

        Upgrades.upgradeProxy(proxyAddress, "PositionsLendingPool.sol", "", opts);

        vm.stopBroadcast();

        return PositionsLendingPool(proxyAddress);
    }
}

contract CreateLendingPool is Script {
    /// @notice Create a new lending pool for an asset
    /// @param lendingPoolProxy The PositionsLendingPool proxy address
    /// @param asset The asset address to create a pool for
    function run(address lendingPoolProxy, address asset) public {
        require(lendingPoolProxy != address(0), "LendingPool proxy address cannot be zero");
        require(asset != address(0), "Asset address cannot be zero");

        vm.startBroadcast();

        PositionsLendingPool(lendingPoolProxy).createLendingPool(
            asset,
            PositionsLendingPool.InterestRateModel({
                baseRate: 0,
                slope1: 675000000000000000000000000,
                slope2: 750000000000000000000000000,
                optimalUtilization: 750000000000000000000000000
            })
        );

        vm.stopBroadcast();
    }
}
