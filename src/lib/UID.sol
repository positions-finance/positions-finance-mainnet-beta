// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library UID {
    function generate(uint256 _nonce, uint256 _chainId, uint256 _nftId, address _protocol)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_nonce, _chainId, _nftId, _protocol));
    }
}
