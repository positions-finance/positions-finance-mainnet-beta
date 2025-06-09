//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std-1.9.7/src/Script.sol";
import {HelperConfig, NetworkConfig} from "./HelperConfig.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades-0.4.0/src/Upgrades.sol";
import {PositionsNFT} from "@src/poc/PositionsNFT.sol";
import {Options} from "openzeppelin-foundry-upgrades-0.4.0/src/Options.sol";

contract DeployNFT is Script {
    HelperConfig helperConfig;

    function run() public returns (HelperConfig, PositionsNFT) {
        helperConfig = new HelperConfig();
        NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        vm.startBroadcast();

        address proxy =
            Upgrades.deployUUPSProxy("PositionsNFT.sol", abi.encodeCall(PositionsNFT.initialize, (config.admin)), opts);
        PositionsNFT(proxy).pauseTransfers();

        vm.stopBroadcast();

        return (helperConfig, PositionsNFT(proxy));
    }
}
