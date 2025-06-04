// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";

import {ChainIds} from "@script/utils/ChainIds.sol";

contract VaultsEntrypointHelperConfig is Script, ChainIds {
    struct NetworkConfig {
        address admin;
        address upgrader;
        address relayer;
    }

    NetworkConfig public activeNetworkConfig;

    error HelperConfig__UnsupportedChain(uint256 chainId);

    constructor() {
        if (block.chainid == HOLESKY_TESTNET_CHAIN_ID) {
            activeNetworkConfig = _getHoleskyTestnetConfig();
        } else if (block.chainid == BEPOLIA_CHAIN_ID) {
            activeNetworkConfig = _getBepoliaConfig();
        } else {
            revert HelperConfig__UnsupportedChain(block.chainid);
        }
    }

    function _getHoleskyTestnetConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            upgrader: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            relayer: 0xC72504dB6a5e069FBF453897f29A5aAE9ce4666A
        });
    }

    function _getBepoliaConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            upgrader: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            relayer: 0x7233Db9c06D301a8C12f1738aAF722bBB32a0A5E
        });
    }

    function _getPegasusConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            upgrader: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            relayer: 0xab2E47DbFcce1DAEB527fD4FEdAF0d9C7BC6460A
        });
    }

    function getActiveNetworkConfig() external view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
