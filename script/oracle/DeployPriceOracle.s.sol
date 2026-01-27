// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PriceOracle} from "@src/oracle/PriceOracle.sol";

contract DeployPriceOracleScript is Script {
    PriceOracle public oracle;

    function run() public returns (PriceOracle) {
        vm.startBroadcast();

        oracle = new PriceOracle();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(oracle),
            abi.encodeCall(
                PriceOracle.initialize,
                (
                    0x35f6e214676208fd20dCD93d19f10e909FF2Bb8e,  // admin
                    0x35f6e214676208fd20dCD93d19f10e909FF2Bb8e,  // upgrader
                    0x98Fd8A40528FC3BD92c6F231bEe0551295FeCeE4   // operator
                )
            )
        );

        vm.stopBroadcast();
        return (PriceOracle(address(proxy)));
    }
}