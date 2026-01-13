// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {LendingPoolHelperConfig} from "./LendingPoolHelperConfig.sol";
import {PositionsLendingPoolHandler} from "@src/handlers/lendingPool/PositionsLendingPoolHandler.sol";

contract DeployPositionsLendingPoolHandler is Script {
    /// @notice Deploy with addresses passed as parameters (recommended for mainnet)
    /// @param entrypoint The PositionsVaultsEntrypoint proxy address
    /// @param lendingPool The PositionsLendingPool proxy address
    function run(address entrypoint, address lendingPool) public returns (PositionsLendingPoolHandler) {
        LendingPoolHelperConfig.NetworkConfig memory config = (new LendingPoolHelperConfig()).getActiveNetworkConfig();

        require(entrypoint != address(0), "Entrypoint address cannot be zero");
        require(lendingPool != address(0), "LendingPool address cannot be zero");

        vm.startBroadcast();
        PositionsLendingPoolHandler lendingPoolHandler = new PositionsLendingPoolHandler();

        PositionsLendingPoolHandler proxy = PositionsLendingPoolHandler(
            payable(
                address(
                    new ERC1967Proxy(
                        address(lendingPoolHandler),
                        abi.encodeWithSelector(
                            PositionsLendingPoolHandler.initialize.selector,
                            entrypoint,
                            lendingPool,
                            config.admin,
                            config.upgrader
                        )
                    )
                )
            )
        );
        vm.stopBroadcast();

        return proxy;
    }

    /// @notice Deploy using addresses from config (if pre-configured)
    function run() public returns (PositionsLendingPoolHandler) {
        LendingPoolHelperConfig.NetworkConfig memory config = (new LendingPoolHelperConfig()).getActiveNetworkConfig();

        require(config.entrypoint != address(0), "Entrypoint not configured - use run(entrypoint, lendingPool) instead");
        require(config.lendingPool != address(0), "LendingPool not configured - use run(entrypoint, lendingPool) instead");

        return run(config.entrypoint, config.lendingPool);
    }
}

contract UpgradePositionsLendingPoolHandler is Script {
    /// @notice Upgrade an existing LendingPoolHandler proxy
    /// @param proxyAddress The existing proxy address to upgrade
    function run(address proxyAddress) public {
        require(proxyAddress != address(0), "Proxy address cannot be zero");

        vm.startBroadcast();
        PositionsLendingPoolHandler(proxyAddress).upgradeToAndCall(
            address(new PositionsLendingPoolHandler()), ""
        );
        vm.stopBroadcast();
    }
}
