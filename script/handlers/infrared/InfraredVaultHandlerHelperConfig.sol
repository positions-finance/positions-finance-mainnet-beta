// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";

import {ChainIds} from "@script/utils/ChainIds.sol";

contract InfraredVaultHandlerHelperConfig is ChainIds {
    struct NetworkConfig {
        address admin;
        uint16 rewardFee;
        address upgrader;
        address entryPoint;
        address relayer;
    }

    NetworkConfig public networkConfig;

    error Errors__UnsupportedChain(uint256 chainId);

    constructor() {
        if (block.chainid == 31337) {
            networkConfig = getAnvilConfig();
        } else if (block.chainid == BEPOLIA_CHAIN_ID) {
            networkConfig = getBepoliaConfig();
        } else if (block.chainid == BERACHAIN_MAINNET_CHAIN_ID) {
            networkConfig = getBerachainConfig();
        } else {
            revert Errors__UnsupportedChain(block.chainid);
        }
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return networkConfig;
    }

    function getAnvilConfig() internal pure returns (NetworkConfig memory) {
        // placeholder values, change on each run

        return NetworkConfig({
            admin: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, //Anvil's default address[0],
            rewardFee: 500,
            upgrader: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            entryPoint: address(0),
            relayer: address(0)
        });
    }

    function getBepoliaConfig() internal pure returns (NetworkConfig memory) {
        // placeholder values, change on each run

        return NetworkConfig({
            admin: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            rewardFee: 500,
            upgrader: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            entryPoint: 0x109c070e2A0C641d9B1A883B453DBb1C46FFA201,
            relayer: 0x70878A44f730aafb4C231cC8b921e257cC204E39
        });
    }

    function getBerachainConfig() internal pure returns (NetworkConfig memory) {
        // placeholder values, change on each run

        return NetworkConfig({
            admin: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            rewardFee: 500,
            upgrader: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            entryPoint: 0x197DaBDa06FeB7681DB97D98db0fCa1ba9402004,
            relayer: 0x7477a2fb34180486D36B5aBDfa59136bCA061C17
        });
    }
}
