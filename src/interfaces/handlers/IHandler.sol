//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPositionsVaultsEntrypoint} from "../entryPoint/IPositionsVaultsEntrypoint.sol";

import {UserVaultBalance} from "../../utils/PositionsDataProvider.sol";

interface IHandler {
    function deposit(address _token, uint256 _amount, uint256 _tokenId, bytes calldata _additionalData) external;
    function queueWithdraw(address _token, uint256 _amount, uint256 _tokenId, bytes calldata _additionalData)
        external;
    function completeWithdraw(
        IPositionsVaultsEntrypoint.WithdrawData memory _withdrawData,
        address _to,
        bytes calldata _additionalData
    ) external returns (address, uint256);
    function liquidate(
        address _token,
        uint256 _amount,
        uint256 _tokenId,
        address _liquidator,
        bytes calldata _additionalData
    ) external;
    function completeLiquidation(
        IPositionsVaultsEntrypoint.WithdrawData memory _withdrawData,
        bytes calldata _additionalData
    ) external returns (address, uint256);
    function withdrawalRequestAccepted(IPositionsVaultsEntrypoint.WithdrawData memory _withdrawData) external;
    function getUserVaultsBalance(uint256 _tokenId) external view returns (UserVaultBalance[] memory);
}
