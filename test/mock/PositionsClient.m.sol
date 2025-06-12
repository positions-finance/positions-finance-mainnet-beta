//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {IPositionsClient} from "@src/interfaces/poc/IPositionsClient.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/AccessControlUpgradeable.sol";
import {IPositionsRelayer} from "@src/interfaces/poc/IPositionsRelayer.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PositionsClient is IPositionsClient, Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    bytes32 public nftOwnershipRoot;
    address public relayer;

    mapping(uint256 => mapping(bytes32 => uint256)) public utilizations;
    mapping(bytes32 => IPositionsRelayer.PositionsCollateralRequest) public collateralRequests;

    event CollateralRequestFulfilled(bytes32 requestId);
    event RequestSent(bytes32 requestId);

    modifier onlyRelayer() {
        if (msg.sender != relayer) {
            revert("PositionsClient: not relayer");
        }
        _;
    }

    function __PositionsClient_init(address _admin, address _relayer) public initializer {
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        relayer = _relayer;
    }

    function requestCollateral(
        IPositionsRelayer.PositionsCollateralRequest memory _collateralRequest,
        bytes memory singature
    ) external returns (bytes32 requestId) {
        requestId = IPositionsRelayer(relayer).requestCollateral(_collateralRequest, singature);
        collateralRequests[requestId] = _collateralRequest;
        emit RequestSent(requestId);
    }

    function utilization(uint256 _tokenId, bytes32 _requestId) external view override returns (uint256) {
        return utilizations[_tokenId][_requestId];
    }

    function fullfillCollateralRequest(bytes32 _requestId) external override onlyRelayer {
        SafeERC20.safeTransfer(
            IERC20(collateralRequests[_requestId].token), relayer, collateralRequests[_requestId].tokenAmount
        );
    }

    // Setter methods for testing

    function setUtilization(uint256 _tokenId, bytes32 _requestId, uint256 _utilization) public {
        // do nothing
        utilizations[_tokenId][_requestId] = _utilization;
    }

    function setRelayer(address _relayer) public onlyRole(DEFAULT_ADMIN_ROLE) {
        relayer = _relayer;
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
