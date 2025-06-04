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

    function getActiveNetworkConfig() external view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
