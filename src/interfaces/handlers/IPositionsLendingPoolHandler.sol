// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPositionsLendingPoolHandler {
    /// @notice Attributes a deposit the lending pool has already supplied under this handler to an Nft.
    function creditSettledDeposit(address _token, uint256 _amount, uint256 _tokenId) external;
}
