// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {UniV3HelperConfig} from "./UniV3HelperConfig.sol";
import {PositionsUniV3Handler} from "@src/handlers/uniV3/PositionsUniV3Handler.sol";

contract DeployPositionsUniV3Handler is Script {
    function run() public returns (PositionsUniV3Handler) {
        UniV3HelperConfig.NetworkConfig memory config = (new UniV3HelperConfig()).getActiveNetworkConfig();

        vm.startBroadcast();
        PositionsUniV3Handler uniV3Handler = new PositionsUniV3Handler();

        PositionsUniV3Handler proxy = PositionsUniV3Handler(
            payable(
                address(
                    new ERC1967Proxy(
                        address(uniV3Handler),
                        abi.encodeWithSelector(
                            PositionsUniV3Handler.initialize.selector,
                            config.relayer,
                            config.nonFungiblePositionManager,
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
