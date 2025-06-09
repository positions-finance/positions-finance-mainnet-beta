// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract ChainIds {
    uint64 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint64 public constant HOLESKY_TESTNET_CHAIN_ID = 17000;
    uint64 public constant BEPOLIA_CHAIN_ID = 80069;
    uint64 constant ARB_SEPOLIA_CHAIN_ID = 421614;
    uint64 constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;
    uint64 constant BOBA_SEPOLIA_CHAIN_ID = 28882;
    uint64 constant MANTA_SEPOLIA_CHAIN_ID = 3441006;
    uint64 constant MONAD_CHAIN_ID = 10143;
    uint256 public constant BERACHAIN_MAINNET_CHAIN_ID = 80094;
    uint64 public constant ARBITRUM_MAINNET_CHAIN_ID = 42161;
}
