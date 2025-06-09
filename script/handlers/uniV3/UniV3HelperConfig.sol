// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";

import {ChainIds} from "../../utils/ChainIds.sol";

contract UniV3HelperConfig is Script, ChainIds {
    struct NetworkConfig {
        address relayer;
        address nonFungiblePositionManager;
        address admin;
        address upgrader;
    }

    NetworkConfig private activeNetworkConfig;

    error HelperConfig__UnsupportedChain(uint256 chainId);

    constructor() {
        if (block.chainid == ETH_MAINNET_CHAIN_ID) {
            activeNetworkConfig = _getEthConfig();
        } else if (block.chainid == BEPOLIA_CHAIN_ID) {
            activeNetworkConfig = _getBepoliaConfig();
        } else if (block.chainid == ARBITRUM_MAINNET_CHAIN_ID) {
            activeNetworkConfig = _getArbitrumConfig();
        } else {
            revert HelperConfig__UnsupportedChain(block.chainid);
        }
    }

    function _getEthConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            relayer: address(0),
            nonFungiblePositionManager: address(0),
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            upgrader: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687
        });
    }

    function _getBepoliaConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            relayer: address(0),
            nonFungiblePositionManager: address(0),
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            upgrader: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687
        });
    }

    function _getArbitrumConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            relayer: 0xB8fba279f495f92A2D8410543A247862a8856ae1,
            nonFungiblePositionManager: 0xC36442b4a4522E871399CD717aBDD847Ab11FE88,
            admin: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            upgrader: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF
        });
    }

    function getActiveNetworkConfig() external view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
