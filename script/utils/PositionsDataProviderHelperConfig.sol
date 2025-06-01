// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std-1.9.7/src/Script.sol";

import {ChainIds} from "./ChainIds.sol";

contract PositionsDataProviderHelperConfig is Script, ChainIds {
    struct NetworkConfig {
        address entrypoint;
        address lendingPool;
    }

    NetworkConfig public activeNetworkConfig;

    error HelperConfig__UnsupportedChain(uint256 chainId);

    constructor() {
        if (block.chainid == HOLESKY_TESTNET_CHAIN_ID) {
            activeNetworkConfig = _getHoleskyTestnetConfig();
        } else if (block.chainid == BEPOLIA_CHAIN_ID) {
            activeNetworkConfig = _getBepoliaConfig();
        } else if (block.chainid == PEGASUS_CHAIN_ID) {
            activeNetworkConfig = _getPegasusConfig();
        } else if (block.chainid == ARB_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = _getArbSepoliaConfig();
        } else if (block.chainid == BOBA_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = _getBobaSepoliaConfig();
        } else if (block.chainid == MANTA_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = _getMantaSepoliaConfig();
        } else if (block.chainid == UNICHAIN_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = _getUnichainSepoliaConfig();
        } else if (block.chainid == MONAD_CHAIN_ID) {
            activeNetworkConfig = _getMonadConfig();
        } else {
            revert HelperConfig__UnsupportedChain(block.chainid);
        }
    }

    function _getHoleskyTestnetConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entrypoint: 0xa0B2fC19CE36A9D0C1231f0C69055b71391C091A,
            lendingPool: 0xCBcd292c9DAE11875E090Bb963aA4C74ccCE6a23
        });
    }

    function _getBepoliaConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entrypoint: 0x69b4CA1Dc34E234738Ce4Efe900b7Cc3e19607d6,
            lendingPool: 0xcFD775857cc33F08f731F3049FF43848BC75D34C
        });
    }

    function _getPegasusConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entrypoint: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687,
            lendingPool: 0xE5261f469bAc513C0a0575A3b686847F48Bc6687
        });
    }

    function _getArbSepoliaConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({entrypoint: address(0), lendingPool: 0x0090Be4c2f70c770352601E000cfe7DdceB2Af79});
    }

    function _getBobaSepoliaConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({entrypoint: address(0), lendingPool: 0x2BF77E076De1544d5Ca6C881cE3dF7a3715DF7ac});
    }

    function _getMantaSepoliaConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({entrypoint: address(0), lendingPool: 0xB30d00286C35fC4B95b5C8347eDF8F2f09118A28});
    }

    function _getUnichainSepoliaConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({entrypoint: address(0), lendingPool: 0x764212078a74062F0e23D4B28a4CBA3c325DD330});
    }

    function _getMonadConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({entrypoint: address(0), lendingPool: 0xA8d72E481724B91122E98D2a924E7544CE703C84});
    }

    function getActiveNetworkConfig() external view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
