//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IPositionsClient
 * @author Positions Team
 * @notice
 */
interface IPositionsClient {
    /**
     * @notice Should return the total utilization amount in USD. It could be the total borrowed amount plus the intereset accured
     * or collateral value in loss in a perpetual position. It depends the protocol implementing this interface according to the usage of collateral.
     * @param _tokenId - The PoC NFT token ID
     * @param _requestId - The usage request ID
     */
    function utilization(uint256 _tokenId, bytes32 _requestId) external view returns (uint256);

    /**
     * @notice Should be called by the relayer to fullfil the collateral request
     * @param _requestId - The usage request ID
     */
    function fullfillCollateralRequest(bytes32 _requestId) external;
}
