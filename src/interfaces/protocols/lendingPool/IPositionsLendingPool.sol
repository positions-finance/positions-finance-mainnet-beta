// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UserVaultBalance} from "../../../utils/PositionsDataProvider.sol";

interface IPositionsLendingPool {
    struct InterestRateModel {
        uint256 baseRate;
        uint256 slope1;
        uint256 slope2;
        uint256 optimalUtilization;
    }

    function supply(address _asset, uint256 _amount, address _for) external;
    function withdraw(address _asset, uint256 _amount, address _to) external;
    function getSupportedAssets() external view returns (address[] memory);
    function poolData(address _asset)
        external
        view
        returns (uint256, uint256, uint256, uint256, InterestRateModel memory, uint256);
    function getBalanceWithInterestAccrossAllAssets(address _supplier)
        external
        view
        returns (UserVaultBalance[] memory);
    function borrowForLoops(address _token, uint256 _amount) external;
}
