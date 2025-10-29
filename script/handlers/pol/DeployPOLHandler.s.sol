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

        // PositionsPOLHandler proxy = PositionsPOLHandler(
        //     payable(
        //         address(
        //             new ERC1967Proxy(
        //                 address(polHandler),
        //                 abi.encodeWithSelector(
        //                     PositionsPOLHandler.initialize.selector,
        //                     config.entrypoint,
        //                     config.admin,
        //                     config.rewardFee,
        //                     config.infrared,
        //                     config.oracle,
        //                     config.admin,
        //                     config.upgrader,
        //                     config.relayer,
        //                     config.bgt
        //                 )
        //             )
        //         )
        //     )
        // );
        address[] memory r = new address[](1);
        r[0] = 0xa2c5adB20A446Fa71A1762002E3C9B4Dd37DBAf4;
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x333663051d3cf2862cd3b30dcf8908e2e9efda5fbfd3df14402dcd3aca313cf2;
        proof[1] = 0xa1a2ef90ef1f4c76d7cc2d0dbc1ed1c2e7adf309ffcaec7b8d8be468810c0511;
        PositionsPOLHandler(payable(0x7d88c220B9e50C96cbeBcaB65CA09368F2afe97F)).redeemBGTForIBGT(r, 3, proof);
        vm.stopBroadcast();

        // return proxy;
    }
}
