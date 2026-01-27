// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPriceOracle} from "@src/interfaces/oracle/IPriceOracle.sol";
import {Utils} from "@src/utils/Utils.sol";

contract PriceOracle is UUPSUpgradeable, AccessControlUpgradeable, IPriceOracle {
    bytes32 private constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 private constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 private constant TARGET_DECIMALS = 6;

    mapping(address token => address feed) private s_chainlinkFeeds;
    mapping(address token => Price price) private s_customPrices;
    mapping(address token => uint256 stalenessThreshold) private s_stalenessThreshold;

    /// @notice Initializes the contract with administrative roles.
    function initialize(address _admin, address _upgrader, address _operator) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _upgrader);
        _grantRole(OPERATOR_ROLE, _operator);
    }

    function setChainlinkFeed(address _token, address _feed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Utils.requireNotAddressZero(_token);
        Utils.requireNotAddressZero(_feed);
        s_chainlinkFeeds[_token] = _feed;
        emit OracleSet(_token, _feed);
    }

    function getPrice(address _token) external view returns (uint256) {
        address feedAddress = s_chainlinkFeeds[_token];

        if (feedAddress != address(0)) {
            AggregatorV3Interface feed = AggregatorV3Interface(feedAddress);
            (uint80 roundId, int256 answer, , uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();

            // Validation: Ensure price is positive and data is not from a failed/incomplete round
            if (answer <= 0) revert PriceOracle__PriceFeedDoesNotExist(_token);
            if (updatedAt == 0 || answeredInRound < roundId) revert PriceOracle__StalePrice(_token, uint256(answer), updatedAt);

            // Staleness Check
            if (block.timestamp - updatedAt > s_stalenessThreshold[_token]) {
                revert PriceOracle__StalePrice(_token, uint256(answer), updatedAt);
            }

            // Normalization to 6 decimals
            uint8 feedDecimals = feed.decimals();
            if (feedDecimals >= TARGET_DECIMALS) {
                return uint256(answer) / (10 ** (feedDecimals - TARGET_DECIMALS));
            } else {
                return uint256(answer) * (10 ** (TARGET_DECIMALS - feedDecimals));
            }
        }

        Price memory priceStruct = s_customPrices[_token];
        if (priceStruct.price == 0) revert PriceOracle__PriceFeedDoesNotExist(_token);
        if (priceStruct.lastUpdatedAt + s_stalenessThreshold[_token] < block.timestamp) {
            revert PriceOracle__StalePrice(_token, priceStruct.price, priceStruct.lastUpdatedAt);
        }

        return priceStruct.price;
    }

    function setStalenessThreshold(address _token, uint256 _thresh) external onlyRole(DEFAULT_ADMIN_ROLE) {
        s_stalenessThreshold[_token] = _thresh;
        emit StalenessThresholdSet(_token, _thresh);
    }

    function setPrice(address _token, uint256 _price) external onlyRole(OPERATOR_ROLE) {
        if (s_chainlinkFeeds[_token] != address(0)) revert PriceOracle__ChainlinkFeedExists();
        s_customPrices[_token] = Price({price: _price, lastUpdatedAt: block.timestamp});
        emit PriceUpdated(_token, _price, block.timestamp);
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    function getUpgraderRole() external pure returns (bytes32) {return UPGRADER_ROLE;}

    function getOperatorRole() external pure returns (bytes32) {return OPERATOR_ROLE;}

    function getCustomPriceStruct(address _t) external view returns (Price memory) {return s_customPrices[_t];}

    function getStalenessThreshold(address _t) external view returns (uint256) {return s_stalenessThreshold[_t];}
}