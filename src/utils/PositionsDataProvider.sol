// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPositionsVaultsEntrypoint} from "../interfaces/entryPoint/IPositionsVaultsEntrypoint.sol";
import {IHandler} from "../interfaces/handlers/IHandler.sol";
import {IPositionsLendingPool} from "../interfaces/protocols/lendingPool/IPositionsLendingPool.sol";

struct UserVaultBalance {
    address handler;
    address vaultOrStrategy;
    address asset;
    uint256 balance;
}

/// @title PositionsDataProvider.
/// @author Positions Team.
/// @notice Aggregates and provides a user's asset balance accross all vaults on different handlers.
contract PositionsDataProvider {
    /// @notice The entrypoint contract address.
    address public immutable entrypoint;
    /// @notice The positions lending pool contract address.
    address public immutable lendingPool;

    /// @notice Initializes the contract.
    /// @param _entrypoint The entrypoint contract address.
    constructor(address _entrypoint, address _lendingPool) {
        entrypoint = _entrypoint;
        lendingPool = _lendingPool;
    }

    /// @notice Gets a user's Nft tokenId's balance accross all vaults on different handlers.
    /// @param _tokenId The user's Nft tokenId.
    function getUserVaultsBalance(uint256 _tokenId) external view returns (UserVaultBalance[][] memory) {
        address[] memory handlers = IPositionsVaultsEntrypoint(entrypoint).getSupportedHandlers();
        uint256 length = handlers.length;

        UserVaultBalance[][] memory userVaultBalance;

        for (uint256 i; i < length; ++i) {
            userVaultBalance[i] = IHandler(handlers[i]).getUserVaultsBalance(_tokenId);
        }

        return userVaultBalance;
    }

    /// @notice Gets a user's Nft tokenId's balance accross all vaults on different handlers.
    /// @param _lender The lender address.
    function getUserBalanceInLendingPool(address _lender) external view returns (UserVaultBalance[] memory) {
        UserVaultBalance[] memory userLendingPoolBalance =
            IPositionsLendingPool(lendingPool).getBalanceWithInterestAccrossAllAssets(_lender);

        return userLendingPoolBalance;
    }
}
