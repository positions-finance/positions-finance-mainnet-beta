//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std-1.9.7/src/Script.sol";

struct NetworkConfig {
    address admin;
    address positionsRelayer;
    uint256 initialReserveFactor;
    address[] assets;
    address oracle;
}

uint64 constant ANVIL_CHAIN_ID = 31337;
uint64 constant HOLESKY_CHAIN_ID = 17000;
uint64 constant BEPOLIA_CHAIN_ID = 80069;
uint64 constant ARB_SEPOLIA_CHAIN_ID = 421614;
uint64 constant PEGASUS_CHAIN_ID = 1891;
uint64 constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;
uint64 constant BOBA_SEPOLIA_CHAIN_ID = 28882;
uint64 constant MANTA_SEPOLIA_CHAIN_ID = 3441006;

contract HelperConfigLendingPool is Script {
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
        } else {
            revert("Unsupported chain");
        }
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return networkConfig;
    }

    function getAnvilConfig() internal pure returns (NetworkConfig memory) {
        address[] memory assets = new address[](4);
        assets[0] = 0x11Aa2a947A17c77cE6F2CD9470e22799DE6dC5B7; // weth placeholder
        assets[1] = 0xa8662Bd551954Ba81aF4bCA286eddcc07B9e0CbA; // usdc placeholder
        assets[2] = 0x38c34984FebDb6079afe03E3cc7de791B5dd3b13; // usdt placeholder
        assets[3] = 0x772737e8f4c59C610cD49A49EE16FCC8947C40A4; // wbtc placeholder

        return NetworkConfig({
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            positionsRelayer: address(1), // placeholder, change on each run
            initialReserveFactor: 1e3,
            assets: assets,
            oracle: address(0)
        });
    }

    function getHoleskyConfig() internal pure returns (NetworkConfig memory) {
        address[] memory assets = new address[](4);
        assets[0] = 0x11Aa2a947A17c77cE6F2CD9470e22799DE6dC5B7; // weth
        assets[1] = 0xa8662Bd551954Ba81aF4bCA286eddcc07B9e0CbA; // usdc
        assets[2] = 0x38c34984FebDb6079afe03E3cc7de791B5dd3b13; // usdt
        assets[3] = 0x772737e8f4c59C610cD49A49EE16FCC8947C40A4; // wbtc

        return NetworkConfig({
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            positionsRelayer: 0x52C545dC455C3DD4F9792BE4576A824a64773252, // placeholder, change on each run
            initialReserveFactor: 1e3,
            assets: assets,
            oracle: address(0)
        });
    }

    function getBepoliaConfig() internal pure returns (NetworkConfig memory) {
        address[] memory assets = new address[](2);
        assets[0] = 0x6969696969696969696969696969696969696969; // wbera
        assets[1] = 0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce; // honey

        return NetworkConfig({
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            positionsRelayer: 0x7B8fcfDA1541A80FD64887261CC2Db83648F1ECF, // placeholder, change on each run
            initialReserveFactor: 1e3,
            assets: assets,
            oracle: 0x015c370898501d6754c6E313b05D51F8bEb79FE4
        });
    }

    function getArbitrumSepoliaConfig() internal pure returns (NetworkConfig memory) {
        address[] memory assets = new address[](4);
        assets[0] = 0xB41A8cC50C257d2d2a89f5b2957Ae52532f79F31; // weth
        assets[1] = 0xD41aEb76B200249437fF727A1F29F179E5d5B3cc; // usdc
        assets[2] = 0xF66878C5be87fB30188BffEcf0DCa92f4dF6da92; // usdt
        assets[3] = 0xF6C44bFd0dE9a37D60D1C65E0D3b7D5A7561aBf3; // wbtc

        return NetworkConfig({
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            positionsRelayer: 0x1cCF0914040e65AB00dC97351d9DdE54A04729F6, // placeholder, change on each run
            initialReserveFactor: 1e3,
            assets: assets,
            oracle: address(0)
        });
    }

    function getPegasusConfig() internal pure returns (NetworkConfig memory) {
        address[] memory assets = new address[](4);
        assets[0] = 0xf257d82568E4Db49b0BAf4292188fefdE1536107; // weth
        assets[1] = 0xF300F63656F3263edf3e702055b1ddb75Be2c6E2; // usdc
        assets[2] = 0x9C3317e719F93b10322D8CbeeCA971ebc2a930E8; // usdt
        assets[3] = 0xaD5B84FA6609f4A7d903f505704ea61bef59D6e1; // wbtc

        return NetworkConfig({
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            positionsRelayer: 0x812D34B687Cc8046ba7A72CdcAA038dDCA4b49E8, // placeholder, change on each run
            initialReserveFactor: 1e3,
            assets: assets,
            oracle: address(0)
        });
    }

    function getUnichainSepoliaConfig() internal pure returns (NetworkConfig memory) {
        address[] memory assets = new address[](4);
        assets[0] = 0x0cAaD0D599e0B6889bCDA3903eB179Bd6Fa3b545; // weth
        assets[1] = 0xdF546DB687c375F1b7874dc6A12D1422cA08C59A; // usdc
        assets[2] = 0xA60858a98bcd8c33fDCf1a15da590B1eB014A406; // usdt
        assets[3] = 0xbC621069069c92bCE2ceA34a5a608679f6C84Eb4; // wbtc

        return NetworkConfig({
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            positionsRelayer: 0x687217B260fe14Dd3C0c22BCc063343901506bF7, // placeholder, change on each run
            initialReserveFactor: 1e3,
            assets: assets,
            oracle: address(0)
        });
    }

    function getBobaSepoliaConfig() internal pure returns (NetworkConfig memory) {
        address[] memory assets = new address[](4);
        assets[0] = 0x6343A0373f84db61d138a777a17292BEF475616e; // weth
        assets[1] = 0xEa97BB908449a14f8b8620dE52418e920a1EcFBE; // usdc
        assets[2] = 0x3E93a6a88F1bd2fA7b85aE7355Ce61e3D26560Fd; // usdt
        assets[3] = 0x92AD06577315eE66Aa915aDFded42D51d39BA08C; // wbtc

        return NetworkConfig({
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            positionsRelayer: 0x687217B260fe14Dd3C0c22BCc063343901506bF7, // placeholder, change on each run
            initialReserveFactor: 1e3,
            assets: assets,
            oracle: address(0)
        });
    }

    function getMantaSepoliaConfig() internal pure returns (NetworkConfig memory) {
        address[] memory assets = new address[](4);
        assets[0] = 0x49A01342791c382Ebf66819F221154960080cA2D; // weth
        assets[1] = 0x53FB3eb5Df89c1263BAEEe4a967030f45eC94DE8; // usdc
        assets[2] = 0x172Aa67f2dAE15E47e61623aFdfEAB9Ed80fAaE6; // usdt
        assets[3] = 0x2BdE71213545a65dFb707719af940c324bADFcCA; // wbtc

        return NetworkConfig({
            admin: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            positionsRelayer: 0x0262d9b1C178A216da78DDB386E05D2BB3086149, // placeholder, change on each run
            initialReserveFactor: 1e3,
            assets: assets,
            oracle: address(0)
        });
    }
}
