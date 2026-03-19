// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";
import {console} from "forge-std-1.9.7/src/console.sol";
import { PolymarketVault } from "../../src/polymarket/PolymarketVault.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployPolymarketVault is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy UUPS Proxy with the implementation
        // Initialize with deployer (msg.sender) as both Owner and Operator
        address proxy = Upgrades.deployUUPSProxy(
            "PolymarketVault.sol:PolymarketVault",
            abi.encodeCall(PolymarketVault.initialize, (msg.sender, msg.sender))
        );

        console.log("PolymarketVault Implementation deployed (handled by Upgrades)");
        console.log("PolymarketVault Proxy deployed at:", proxy);

        vm.stopBroadcast();
    }
}

//forge script script/polymarket/DeployPolymarketVault.s.sol --rpc-url rpc --broadcast --private-key key  --ffi


