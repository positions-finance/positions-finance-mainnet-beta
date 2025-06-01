//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {VaultsEntrypointHelperConfig} from "./VaultsEntrypointHelperConfig.sol";
import {PositionsVaultsEntrypoint} from "@src/entryPoint/PositionsVaultsEntrypoint.sol";

contract DeployPositionsVaultsEntrypoint is Script {
    VaultsEntrypointHelperConfig public helperConfig;
    PositionsVaultsEntrypoint public entrypoint;

    function run() public returns (PositionsVaultsEntrypoint) {
        helperConfig = new VaultsEntrypointHelperConfig();
        VaultsEntrypointHelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        vm.startBroadcast();
        entrypoint = new PositionsVaultsEntrypoint();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(entrypoint),
            abi.encodeCall(PositionsVaultsEntrypoint.initialize, (config.admin, config.upgrader, config.relayer))
        );
        vm.stopBroadcast();

        return (PositionsVaultsEntrypoint(address(proxy)));
    }
}
