// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceOracle {
    struct Price {
        uint256 price;
        uint256 lastUpdatedAt;
    }

    event OracleSet(address token, address oracleAddress);
    event StalenessThresholdSet(address token, uint256 stalenessThreshold);
    event PriceUpdated(address token, uint256 price, uint256 updatedAt);

    error PriceOracle__ChainlinkFeedExists();
    error PriceOracle__StalePrice(address token, uint256 price, uint256 updatedAt);
    error PriceOracle__PriceFeedDoesNotExist(address token);

    function initialize(address _admin, address _upgrader, address _operator) external;

    function setStalenessThreshold(address _token, uint256 _stalenessThreshold) external;

    function setPrice(address _token, uint256 _price) external;

    function getPrice(address _asset) external view returns (uint256);

    function getUpgraderRole() external pure returns (bytes32);

    function getOperatorRole() external pure returns (bytes32);

    function getCustomPriceStruct(address _token) external view returns (Price memory);

    function getStalenessThreshold(address _token) external view returns (uint256);
}