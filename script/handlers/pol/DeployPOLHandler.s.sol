// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {POLHelperConfig} from "./POLHelperConfig.sol";
import {PositionsPOLHandler} from "@src/handlers/pol/PositionsPOLHandler.sol";

contract DeployPOLHandler is Script {
    function run() public returns (PositionsPOLHandler) {
        POLHelperConfig.NetworkConfig memory config = (new POLHelperConfig()).getActiveNetworkConfig();

        vm.startBroadcast();
        PositionsPOLHandler polHandler = new PositionsPOLHandler();

        PositionsPOLHandler proxy = PositionsPOLHandler(
            payable(
                address(
                    new ERC1967Proxy(
                        address(polHandler),
                        abi.encodeWithSelector(
                            PositionsPOLHandler.initialize.selector,
                            config.entrypoint,
                            config.admin,
                            config.upgrader,
                            config.relayer,
                            config.bgt
                        )
                    )
                )
            )
        );
        vm.stopBroadcast();

        return proxy;
    }
}
