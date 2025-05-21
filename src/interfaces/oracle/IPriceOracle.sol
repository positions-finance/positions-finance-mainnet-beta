// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceOracle {
    /// @notice Returns the asset price in USD denomination with 18 decimal precision.
    /// @param asset The asset address.
    /// @return The asset price in USD denomination with 18 decimal precision
    function getPrice(address asset) external view returns (uint256);
}
