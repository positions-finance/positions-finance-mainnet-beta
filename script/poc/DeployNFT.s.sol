//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";
import {HelperConfig, NetworkConfig} from "./HelperConfig.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {PositionsNFT} from "@src/poc/PositionsNFT.sol";

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
        // Note: pauseTransfers() must be called by the admin after deployment
        // cast send <NFT_PROXY> "pauseTransfers()" --rpc-url $POLYGON_MAINNET_RPC_URL --private-key <ADMIN_PRIVATE_KEY>

        vm.stopBroadcast();

        return (helperConfig, PositionsNFT(proxy));
    }
}
