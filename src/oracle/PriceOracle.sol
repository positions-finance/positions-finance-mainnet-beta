// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";

import {IPyth} from "@pythnetwork-pyth-sdk-solidity-4.2.0/IPyth.sol";
import {PythUtils} from "@pythnetwork-pyth-sdk-solidity-4.2.0/PythUtils.sol";
import {PythStructs} from "@pythnetwork-pyth-sdk-solidity-4.2.0/PythStructs.sol";
import {IPriceOracle} from "@src/interfaces/oracle/IPriceOracle.sol";

import {Utils} from "@src/utils/Utils.sol";

/// @title PriceOracle.
/// @author Positions Team.
/// @notice A central contract to fetch token prices from Pyth as well as set/
/// update prices for tokens that do not have a Pyth price feed.
contract PriceOracle is UUPSUpgradeable, AccessControlUpgradeable, IPriceOracle {
    /// @dev Upgrader role can upgrade the contract.
    bytes32 private constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @dev Operator role can update custom price feeds.
    bytes32 private constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    /// @dev Constant for 10 ** 18 (Pyth prices have different precision).
    uint256 private constant E18 = 1e18;
    /// @dev Target decimals for price output.
    uint256 private constant TARGET_DECIMALS = 6;
    /// @dev Constant for 10 ** 6.
    uint256 private constant E6 = 1e6;

    /// @dev The Pyth contract address.
    IPyth private s_pyth;
    /// @dev Maps each token with its associated Pyth price ID.
    mapping(address token => bytes32 priceId) private s_pythPriceIds;
    /// @dev Custom prices for tokens which do not have a price feed. For example, LP tokens.
    mapping(address token => Price price) private s_customPrices;
    /// @dev Staleness threshold for oracles.
    mapping(address token => uint256 stalenessThreshold) private s_stalenessThreshold;

    /// @notice Emitted when a Pyth price ID is set for a token.
    /// @param token The token address.
    /// @param priceId The Pyth price ID.
    event PythPriceIdSet(address indexed token, bytes32 indexed priceId);

    /// @notice Emitted when the Pyth contract address is updated.
    /// @param oldPyth The old Pyth contract address.
    /// @param newPyth The new Pyth contract address.
    event PythContractUpdated(address indexed oldPyth, address indexed newPyth);

    /// @notice Initializes the contract.
    /// @param _admin The admin address.
    /// @param _upgrader The upgrader address which receives the upgrader role.
    /// @param _operator The operator address.
    /// @param _pyth The Pyth contract address.
    function initialize(address _admin, address _upgrader, address _operator, address _pyth) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _upgrader);
        _grantRole(OPERATOR_ROLE, _operator);

        Utils.requireNotAddressZero(_pyth);
        s_pyth = IPyth(_pyth);
    }

    /// @notice Allows the admin to set the Pyth contract address.
    /// @param _pyth The new Pyth contract address.
    function setPythContract(address _pyth) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Utils.requireNotAddressZero(_pyth);

        address oldPyth = address(s_pyth);
        s_pyth = IPyth(_pyth);

        emit PythContractUpdated(oldPyth, _pyth);
    }

    /// @notice Allows the admin to set the Pyth price ID for a token.
    /// @param _token The token address.
    /// @param _priceId The Pyth price ID.
    function setPythPriceId(address _token, bytes32 _priceId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Utils.requireNotAddressZero(_token);
        require(_priceId != bytes32(0), "PriceOracle: Invalid price ID");

        s_pythPriceIds[_token] = _priceId;

        emit PythPriceIdSet(_token, _priceId);
        emit OracleSet(_token, address(s_pyth));
    }

    /// @notice Allows the admin to set staleness threshold for tokens.
    /// @param _token The token address.
    /// @param _stalenessThreshold The staleness threshold.
    function setStalenessThreshold(address _token, uint256 _stalenessThreshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Utils.requireNotAddressZero(_token);

        s_stalenessThreshold[_token] = _stalenessThreshold;

        emit StalenessThresholdSet(_token, _stalenessThreshold);
    }

    /// @notice Allows the operator to update the price of a token for which no Pyth price feed exists.
    /// @param _token The token address.
    /// @param _price The price in USD denomination (6 decimals).
    function setPrice(address _token, uint256 _price) external onlyRole(OPERATOR_ROLE) {
        _requirePythPriceFeedDoesNotExist(_token);

        s_customPrices[_token].price = _price;
        s_customPrices[_token].lastUpdatedAt = block.timestamp;

        emit PriceUpdated(_token, _price, block.timestamp);
    }

    /// @notice Gets the price of a token.
    /// @param _token The token address.
    /// @return price The token price in USD with 6 decimal places.
    function getPrice(address _token) external view returns (uint256 price) {
        bytes32 priceId = s_pythPriceIds[_token];

        if (priceId != bytes32(0)) {
            PythStructs.Price memory pythPrice = s_pyth.getPriceNoOlderThan(priceId, s_stalenessThreshold[_token]);

            // Convert Pyth price to target decimals (6)
            return PythUtils.convertToUint(pythPrice.price, pythPrice.expo, uint8(TARGET_DECIMALS));
        }

        Price memory priceStruct = s_customPrices[_token];
        if (priceStruct.price == 0) revert PriceOracle__PriceFeedDoesNotExist(_token);
        if (priceStruct.lastUpdatedAt + s_stalenessThreshold[_token] < block.timestamp) {
            revert PriceOracle__StalePrice(_token, priceStruct.price, priceStruct.lastUpdatedAt);
        }

        return priceStruct.price;
    }

    /// @notice Gets the price of a token with price update data.
    /// @param _token The token address.
    /// @param _priceUpdateData The price update data from Pyth.
    /// @return price The token price in USD with 6 decimal places.
    function getPriceWithUpdate(address _token, bytes[] calldata _priceUpdateData)
        external
        payable
        returns (uint256 price)
    {
        bytes32 priceId = s_pythPriceIds[_token];

        if (priceId != bytes32(0)) {
            // Update the price feeds
            uint256 fee = s_pyth.getUpdateFee(_priceUpdateData);
            s_pyth.updatePriceFeeds{value: fee}(_priceUpdateData);

            PythStructs.Price memory pythPrice = s_pyth.getPriceNoOlderThan(priceId, s_stalenessThreshold[_token]);

            // Check if price is stale
            if (uint256(pythPrice.publishTime) + s_stalenessThreshold[_token] < block.timestamp) {
                revert PriceOracle__StalePrice(_token, uint256(uint64(pythPrice.price)), uint256(pythPrice.publishTime));
            }

            return PythUtils.convertToUint(pythPrice.price, pythPrice.expo, uint8(TARGET_DECIMALS));
        }

        // Fallback to custom prices
        Price memory priceStruct = s_customPrices[_token];
        if (priceStruct.price == 0) revert PriceOracle__PriceFeedDoesNotExist(_token);
        if (priceStruct.lastUpdatedAt + s_stalenessThreshold[_token] < block.timestamp) {
            revert PriceOracle__StalePrice(_token, priceStruct.price, priceStruct.lastUpdatedAt);
        }

        return priceStruct.price;
    }

    /// @notice Checks if a Pyth price feed exists for a token.
    /// @param _token The token address.
    function _requirePythPriceFeedDoesNotExist(address _token) internal view {
        bytes32 priceId = s_pythPriceIds[_token];
        if (priceId != bytes32(0)) revert PriceOracle__Api3ReaderProxyExists(); // Reusing existing error
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}

    /// @notice Gets the upgrader role identifier.
    /// @return The bytes32 upgrader role identifier.
    function getUpgraderRole() external pure returns (bytes32) {
        return UPGRADER_ROLE;
    }

    /// @notice Gets the operator role identifier.
    /// @return The bytes32 operator role identifier.
    function getOperatorRole() external pure returns (bytes32) {
        return OPERATOR_ROLE;
    }

    /// @notice Gets the Pyth contract address.
    /// @return The Pyth contract address.
    function getPythContract() external view returns (address) {
        return address(s_pyth);
    }

    /// @notice Gets the Pyth price ID for a token.
    /// @param _token The token address.
    /// @return The Pyth price ID.
    function getPythPriceId(address _token) external view returns (bytes32) {
        return s_pythPriceIds[_token];
    }

    /// @notice Gets the custom price struct.
    /// @param _token The token address.
    /// @return The price struct holding token price and last updated timestamp.
    function getCustomPriceStruct(address _token) external view returns (Price memory) {
        return s_customPrices[_token];
    }

    /// @notice Gets the staleness threshold for a price feed.
    /// @param _token The token address.
    /// @return The staleness threshold.
    function getStalenessThreshold(address _token) external view returns (uint256) {
        return s_stalenessThreshold[_token];
    }
}
