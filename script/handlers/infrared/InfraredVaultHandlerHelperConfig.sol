// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std-1.9.7/src/Script.sol";

import {ChainIds} from "@script/utils/ChainIds.sol";

contract InfraredVaultHandlerHelperConfig is ChainIds {
    struct NetworkConfig {
        address admin;
        address upgrader;
        address entryPoint;
        address relayer;
        address oracle;
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
            upgrader: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            entryPoint: address(0),
            relayer: address(0),
            oracle: address(0)
        });
    }

    function getBepoliaConfig() internal pure returns (NetworkConfig memory) {
        // placeholder values, change on each run

        return NetworkConfig({
            admin: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            upgrader: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            entryPoint: 0x109c070e2A0C641d9B1A883B453DBb1C46FFA201,
            relayer: 0x70878A44f730aafb4C231cC8b921e257cC204E39,
            oracle: 0x367Ce6186EFB0C2C06E1663A1cE2D59F26c01Ac9
        });
    }

    function getBerachainConfig() internal pure returns (NetworkConfig memory) {
        // placeholder values, change on each run

        return NetworkConfig({
            admin: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            upgrader: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            entryPoint: 0x48bd18FD6c1415DfDCC34abd8CcCB50A6ABca40e,
            relayer: 0xBd955F79b14A7A8c20F661F073b7720c5f522254,
            oracle: 0xEc46dD85dc81eA631B29178F6Db0e1Bc135E7D2B
        });
    }
}
