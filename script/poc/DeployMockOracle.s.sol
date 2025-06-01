//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {PositionsNFT} from "@src/poc/PositionsNFT.sol";

import {UniversalOracle} from "@test/mock/UniversalOracle.sol";
import {HelperConfig, NetworkConfig} from "./HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";

import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployMockOracle is Script {
    HelperConfig helperConfig;

    function run() public returns (HelperConfig, PositionsNFT) {
        helperConfig = new HelperConfig();
        NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        vm.startBroadcast();
        UniversalOracle oracle = new UniversalOracle(config.admin);
        vm.stopBroadcast();

        return (helperConfig, PositionsNFT(address(oracle)));
    }
}
