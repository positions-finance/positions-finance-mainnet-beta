// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";

import {ChainIds} from "@script/utils/ChainIds.sol";

contract POLHelperConfig is Script, ChainIds {
    struct NetworkConfig {
        address entrypoint;
        address admin;
        address upgrader;
        address relayer;
        address bgt;
    }

    NetworkConfig private activeNetworkConfig;

    error HelperConfig__UnsupportedChain(uint256 chainId);

    constructor() {
        if (block.chainid == BEPOLIA_CHAIN_ID) {
            activeNetworkConfig = _getBepoliaConfig();
        } else if (block.chainid == BERACHAIN_MAINNET_CHAIN_ID) {
            activeNetworkConfig = _getBerachainConfig();
        } else {
            revert HelperConfig__UnsupportedChain(block.chainid);
        }
    }

    function _getBepoliaConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entrypoint: 0x69b4CA1Dc34E234738Ce4Efe900b7Cc3e19607d6,
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            upgrader: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            relayer: 0x7B8fcfDA1541A80FD64887261CC2Db83648F1ECF,
            bgt: 0x656b95E550C07a9ffe548bd4085c72418Ceb1dba
        });
    }

    function _getBerachainConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entrypoint: 0x48bd18FD6c1415DfDCC34abd8CcCB50A6ABca40e,
            admin: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            upgrader: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            relayer: 0xBd955F79b14A7A8c20F661F073b7720c5f522254,
            bgt: 0x656b95E550C07a9ffe548bd4085c72418Ceb1dba
        });
    }

    function getActiveNetworkConfig() external view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
