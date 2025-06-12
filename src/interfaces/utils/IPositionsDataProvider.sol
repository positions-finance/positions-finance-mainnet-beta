// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPositionsDataProvider {
    struct UserVaultBalance {
        address handler;
        address vaultOrStrategy;
        address asset;
        uint256 balance;
    }

    event EntryPointSet(address entryPoint);

    function getEntryPoint() external view returns (address);
    function getUserVaultsBalance(uint256 _tokenId) external view returns (UserVaultBalance[][] memory);
}
