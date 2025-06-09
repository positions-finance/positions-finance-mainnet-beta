// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";

import {ChainIds} from "../../utils/ChainIds.sol";

contract LendingPoolHelperConfig is Script, ChainIds {
    struct NetworkConfig {
        address entrypoint;
        address admin;
        address upgrader;
        address lendingPool;
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

    function _getPegasusConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entrypoint: address(0),
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            upgrader: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            lendingPool: 0x68190A0083b21085638Ab6b3310FEB592b3DD84f
        });
    }

    function _getBepoliaConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entrypoint: 0x69b4CA1Dc34E234738Ce4Efe900b7Cc3e19607d6,
            admin: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            upgrader: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            lendingPool: 0xcFD775857cc33F08f731F3049FF43848BC75D34C
        });
    }

    function _getBerachainConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entrypoint: 0x48bd18FD6c1415DfDCC34abd8CcCB50A6ABca40e,
            admin: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            upgrader: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            lendingPool: 0x51B2C76d0259078d8D1a4fb7c844D72D30Dd1420
        });
    }

    function getActiveNetworkConfig() external view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
