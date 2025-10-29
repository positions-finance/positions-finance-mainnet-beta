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
        // entrypoint = new PositionsVaultsEntrypoint();
        // ERC1967Proxy proxy = new ERC1967Proxy(
        //     address(entrypoint),
        //     abi.encodeCall(PositionsVaultsEntrypoint.initialize, (config.admin, config.upgrader, config.relayer))
        // );
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0xcb06499d5564fca6ece421def7cc3627e8338af5d8db0d45e723096619e02475;
        proof[1] = 0x0ab6ae333d21270562d9615c9f55e3f312f1003d9924c08dcc9c54f25ff88693;
        PositionsVaultsEntrypoint(0x197DaBDa06FeB7681DB97D98db0fCa1ba9402004).completeWithdraw(
            0x4Bd56467763F14072beB4A7eE409a77625f4f319,
            0xd75764d8c466642ffbe818e44bb5954a14264ece44275e34a3763b983c2e944b,
            proof,
            abi.encode(0x6969696969696969696969696969696969696969)
        );
        vm.stopBroadcast();

        // return (PositionsVaultsEntrypoint(address(proxy)));
    }
}
