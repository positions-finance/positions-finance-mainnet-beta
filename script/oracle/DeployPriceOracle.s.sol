//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {PriceOracle} from "@src/oracle/PriceOracle.sol";

contract DeployPositionsVaultsEntrypoint is Script {
    PriceOracle public oracle;

    function run() public returns (PriceOracle) {
        vm.startBroadcast();
        oracle = new PriceOracle();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(oracle),
            abi.encodeCall(
                PriceOracle.initialize,
                (
                    0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
                    0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
                    0x7477a2fb34180486D36B5aBDfa59136bCA061C17,
                    0x2880aB155794e7179c9eE2e38200202908C17B43
                )
            )
        );
        vm.stopBroadcast();

        return (PriceOracle(address(proxy)));
    }
}
