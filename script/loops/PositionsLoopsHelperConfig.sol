// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";

import {ChainIds} from "@script/utils/ChainIds.sol";

contract PositionsLoopsHelperConfig is Script, ChainIds {
    struct NetworkConfig {
        address admin;
        address positionsRelayer;
        address lendingPool;
        address islandRouter;
        address island;
        address vault;
        address swapRouter;
        address bgt;
    }

    NetworkConfig public activeNetworkConfig;

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
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            positionsRelayer: address(0),
            lendingPool: address(0),
            swapRouter: 0xEd158C4b336A6FCb5B193A5570e3a571f6cbe690,
            island: 0xFCB24b3b7E87E3810b150d25D5964c566D9A2B6F,
            islandRouter: 0xFCB24b3b7E87E3810b150d25D5964c566D9A2B6F,
            vault: 0xa2c5adB20A446Fa71A1762002E3C9B4Dd37DBAf4,
            bgt: 0x656b95E550C07a9ffe548bd4085c72418Ceb1dba
        });
    }

    function _getBerachainConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            positionsRelayer: 0xBd955F79b14A7A8c20F661F073b7720c5f522254,
            lendingPool: 0x51B2C76d0259078d8D1a4fb7c844D72D30Dd1420,
            swapRouter: 0xEd158C4b336A6FCb5B193A5570e3a571f6cbe690,
            island: 0xE3EeB9e48934634d8B5B39A0d15DD89eE0F969C4,
            islandRouter: 0x679a7C63FC83b6A4D9C1F931891d705483d4791F,
            vault: 0xa2c5adB20A446Fa71A1762002E3C9B4Dd37DBAf4,
            bgt: 0x656b95E550C07a9ffe548bd4085c72418Ceb1dba
        });
    }

    function getActiveNetworkConfig() external view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
