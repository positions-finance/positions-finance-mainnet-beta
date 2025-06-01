// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockRelayer {
    function verifyNFTOwnership(address, uint256, bytes32[] memory) external pure returns (bool) {
        return true;
    }
}
