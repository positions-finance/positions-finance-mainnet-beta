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
        } else if (block.chainid == POLYGON_AMOY_TESTNET_CHAIN_ID) {
            activeNetworkConfig = _getPolygonAmoyConfig();
        } else if (block.chainid == POLYGON_MAINNET_CHAIN_ID) {
            activeNetworkConfig = _getPolygonMainnetConfig();
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
            entrypoint: 0x197DaBDa06FeB7681DB97D98db0fCa1ba9402004,
            admin: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            upgrader: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            lendingPool: 0x501eB689C59c9B577896bcAbcC92bf6926d0B968
        });
    }

    function _getPolygonAmoyConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entrypoint: address(0),  // Will be deployed
            admin: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            upgrader: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            lendingPool: address(0)  // Will be deployed
        });
    }

    function _getPolygonMainnetConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entrypoint: address(0),  // Will be deployed
            admin: 0x35f6e214676208fd20dCD93d19f10e909FF2Bb8e,
            upgrader: 0x35f6e214676208fd20dCD93d19f10e909FF2Bb8e,
            lendingPool: address(0)  // Will be deployed
        });
    }

    function getActiveNetworkConfig() external view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
