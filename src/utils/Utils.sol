// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

library Utils {
    uint256 private constant VALUE_ZERO = 0;
    address private constant ADDRESS_ZERO = address(0);

    error Utils__AddressZero();
    error Utils__ValueZero();
    error Utils__LengthMismatch();
    error Utils__ValueGreaterThanComparisonValue();

    function requireNotAddressZero(address _address) internal pure {
        if (_address == ADDRESS_ZERO) revert Utils__AddressZero();
    }

    function requireNotValueZero(uint256 _value) internal pure {
        if (_value == VALUE_ZERO) revert Utils__ValueZero();
    }

    function requireLengthsMatch(uint256 _length1, uint256 _length2) internal pure {
        if (_length1 != _length2) revert Utils__LengthMismatch();
    }

    function requireNotGreaterThan(uint256 _value, uint256 _toCompareWith) internal pure {
        if (_value > _toCompareWith) revert Utils__ValueGreaterThanComparisonValue();
    }
}
