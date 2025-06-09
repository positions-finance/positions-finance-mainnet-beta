// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PositionsRelayer} from "@src/poc/PositionsRelayer.sol";
import {Script} from "forge-std-1.9.7/src/Script.sol";

struct NetworkConfig {
    address admin;
    address feeReceipient;
    uint256 feePercentage;
}

uint64 constant ANVIL_CHAIN_ID = 31337;
uint64 constant HOLESKY_CHAIN_ID = 17000;
uint64 constant BEPOLIA_CHAIN_ID = 80069;
uint64 constant ARB_SEPOLIA_CHAIN_ID = 421614;
uint64 constant PEGASUS_CHAIN_ID = 1891;
uint64 constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;
uint64 constant BOBA_SEPOLIA_CHAIN_ID = 28882;
uint64 constant MANTA_SEPOLIA_CHAIN_ID = 3441006;
uint64 constant BERACHAIN_MAINNET_CHAIN_ID = 80094;
uint64 constant ARBITRUM_MAINNET_CHAIN_ID = 42161;

contract HelperConfig is Script {
    NetworkConfig networkConfig;

    constructor() {
        if (block.chainid == ANVIL_CHAIN_ID) {
            networkConfig = getAnvilConfig();
        } else if (block.chainid == HOLESKY_CHAIN_ID) {
            networkConfig = getHoleskyConfig();
        } else if (block.chainid == BEPOLIA_CHAIN_ID) {
            networkConfig = getBepoliaConfig();
        } else if (block.chainid == ARB_SEPOLIA_CHAIN_ID) {
            networkConfig = getArbitrumSepoliaConfig();
        } else if (block.chainid == PEGASUS_CHAIN_ID) {
            networkConfig = getPegasusConfig();
        } else if (block.chainid == UNICHAIN_SEPOLIA_CHAIN_ID) {
            networkConfig = getUnichainSepoliaConfig();
        } else if (block.chainid == BOBA_SEPOLIA_CHAIN_ID) {
            networkConfig = getBobaSepoliaConfig();
        } else if (block.chainid == MANTA_SEPOLIA_CHAIN_ID) {
            networkConfig = getMantaSepoliaConfig();
        } else if (block.chainid == BERACHAIN_MAINNET_CHAIN_ID) {
            networkConfig = getBerachainConfig();
        } else if (block.chainid == ARBITRUM_MAINNET_CHAIN_ID) {
            networkConfig = getArbitrumConfig();
        } else {
            revert("Unsupported chain");
        }
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return networkConfig;
    }

    function getAnvilConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            // placeholder values, change on each run
            admin: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, //Anvil's default address[0],
            feeReceipient: 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720, //address[9]
            feePercentage: 100
        });
    }

    function getHoleskyConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            // placeholder values, change on each run
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            feeReceipient: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            feePercentage: 100
        });
    }

    function getBepoliaConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            // placeholder values, change on each run
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            feeReceipient: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            feePercentage: 100
        });
    }

    function getArbitrumSepoliaConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            // placeholder values, change on each run
            admin: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            feeReceipient: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            feePercentage: 100
        });
    }

    function getPegasusConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            // placeholder values, change on each run
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            feeReceipient: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            feePercentage: 100
        });
    }

    function getUnichainSepoliaConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            // placeholder values, change on each run
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            feeReceipient: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            feePercentage: 100
        });
    }

    function getBobaSepoliaConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            // placeholder values, change on each run
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            feeReceipient: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            feePercentage: 100
        });
    }

    function getMantaSepoliaConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            // placeholder values, change on each run
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            feeReceipient: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            feePercentage: 100
        });
    }

    function getBerachainConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            // placeholder values, change on each run
            admin: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            feeReceipient: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            feePercentage: 100
        });
    }

    function getArbitrumConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            // placeholder values, change on each run
            admin: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            feeReceipient: 0x3AC44cA8b613A139E7cCc0Be3e5F9955867bfFDF,
            feePercentage: 100
        });
    }
}

struct NetworkConfigClient {
    address admin;
    address relayer;
}

contract HelperConfigClient is Script {
    NetworkConfigClient networkConfig;

    constructor() {
        if (block.chainid == 31337) {
            networkConfig = getAnvilConfig();
        } else if (block.chainid == HOLESKY_CHAIN_ID) {
            networkConfig = getHoleskyConfig();
        } else if (block.chainid == BEPOLIA_CHAIN_ID) {
            networkConfig = getBepoliaConfig();
        } else {
            revert("Unsupported chain");
        }
    }

    function getActiveNetworkConfig() public view returns (NetworkConfigClient memory) {
        return networkConfig;
    }

    function getHoleskyConfig() internal pure returns (NetworkConfigClient memory) {
        return NetworkConfigClient({
            admin: 0x029412BAfa6D524E547386Db2C20F9ee39e8F0a9,
            relayer: 0x20e425A5B4d342485f696A720d6A7BD1CA0da973 // placeholder, change on each run
        });
    }

    function getBepoliaConfig() internal pure returns (NetworkConfigClient memory) {
        return NetworkConfigClient({
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            relayer: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687 // placeholder, change on each run
        });
    }

    function getAnvilConfig() internal pure returns (NetworkConfigClient memory) {
        return NetworkConfigClient({
            admin: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, //Anvil's default address[0]
            relayer: 0x91fC849F42E78bD12020e1C2a8142474b5777964 //TODO: Write script to deploy and set address locally
        });
    }
}
