// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title UniversalOracle.
/// @author Positions Team.
/// @notice A mock oracle to set and retrieve usd prices of assets in e6 denomination.
contract UniversalOracle is Ownable {
    mapping(address asset => uint256 usdPrice) private assetToUsdPrice;

    event PriceSet(address indexed asset, uint256 indexed price);

    constructor(address _owner) Ownable(_owner) { }

    /// @notice Allows the owner to set the asset price in usd (e6 denomination).
    /// @param _asset The asset address.
    /// @param _price The price of the asset in usd.
    function setPrice(address _asset, uint256 _price) external onlyOwner {
        assetToUsdPrice[_asset] = _price;

        emit PriceSet(_asset, _price);
    }

    /// @notice Gets the price of an asset in usd (e6 denomination).
    /// @param _asset The asset address.
    function getPrice(address _asset) external view returns (uint256) {
        return assetToUsdPrice[_asset];
    }
}
