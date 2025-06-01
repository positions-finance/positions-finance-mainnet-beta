// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {LendingPoolHelperConfig} from "./LendingPoolHelperConfig.sol";
import {PositionsLendingPoolHandler} from "@src/handlers/lendingPool/PositionsLendingPoolHandler.sol";

contract DeployPositionsLendingPoolHandler is Script {
    function run() public returns (PositionsLendingPoolHandler) {
        LendingPoolHelperConfig.NetworkConfig memory config = (new LendingPoolHelperConfig()).getActiveNetworkConfig();

        vm.startBroadcast();
        PositionsLendingPoolHandler lendingPoolHandler = new PositionsLendingPoolHandler();

        PositionsLendingPoolHandler proxy = PositionsLendingPoolHandler(
            payable(
                address(
                    new ERC1967Proxy(
                        address(lendingPoolHandler),
                        abi.encodeWithSelector(
                            PositionsLendingPoolHandler.initialize.selector,
                            config.entrypoint,
                            config.lendingPool,
                            config.admin,
                            config.upgrader
                        )
                    )
                )
            )
        );
        vm.stopBroadcast();

        return (proxy);
    }
}
