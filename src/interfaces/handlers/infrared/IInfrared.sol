// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IInfrared {
    function claimExternalVaultRewards(address _asset, address _user) external;
    function ibgt() external view returns (address);
}
