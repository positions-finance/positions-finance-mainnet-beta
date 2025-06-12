// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPositionsRelayer {
    struct PositionsCollateralRequest {
        uint256 tokenId;
        address protocol;
        address token;
        address owner;
        uint256 tokenAmount;
        uint256 deadline;
        bytes data;
    }

    enum RequestStatus {
        NOT_FOUND,
        PENDING,
        FULLFILED,
        REJECTED,
        FAILED
    }

    struct Acknowledgement {
        address borrower;
        uint256 repaidAmount;
    }

    event NFTOwnershipRootUpdated(bytes32 indexed nftRoot);
    event CollateralRequest(bytes32 indexed requestId, PositionsCollateralRequest collateralRequest, bytes signature);
    event CollateralProcess(bytes32 indexed requestId, RequestStatus status, bytes errorData);
    event Acknowledged(address indexed protocol, bytes32 indexed requestId, Acknowledgement indexed acknowledgement);

    error DeadlinePassed();
    error InsufficientFunds();
    error InvalidSignature();
    error AddressZero();
    error InvalidFeePercentage();

    function RELAYER_ROLE() external pure returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function updateNFTOwnershipRoot(bytes32 _nftRoot) external;
    function collateralRequests(bytes32 requestId) external view returns (PositionsCollateralRequest memory);
    function requestCollateral(PositionsCollateralRequest memory _collateralRequest, bytes memory signature)
        external
        returns (bytes32 requestId);
    function verifyNFTOwnership(address user, uint256 tokenId, bytes32[] calldata proof) external view returns (bool);
}
