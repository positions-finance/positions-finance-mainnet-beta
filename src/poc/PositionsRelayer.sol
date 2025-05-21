//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/IERC20.sol";

import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin-contracts-5.3.0/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MerkleProof.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";

import {IPositionsClient} from "../interfaces/poc/IPositionsClient.sol";
import {IPositionsRelayer} from "../interfaces/poc/IPositionsRelayer.sol";

import {UID} from "../lib/UID.sol";

/// @title PositionsRelayer
/// @author Positions Team
/// @notice Entrypoint into the Positions protocol which serves as an interface for position clients to interact with.
/// The backend tracks events from here as well as processes requests from clients. The positions relayer is deployed on
/// all networks where position clients lie.
contract PositionsRelayer is IPositionsRelayer, Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    /// @notice Only operators with the relayer role can process requests.
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    /// @notice Only operators with the upgrader role can upgrade the proxy's implementation.
    bytes32 public constant UPGRADE_ROLE = keccak256("UPGRADE_ROLE");

    /// @notice The merkle root for verifying Nft ownership accross chains.
    bytes32 public nftOwnershipRoot;
    /// @notice The fee recipient for any accumulated fees within the protocol.
    address public feeReceipient;
    /// @notice The percentage of fees (in bps) to be taken on each successfully filled request.
    uint256 public feePercentage;

    /// @notice Tracking the request nonces to prevent replay attacks.
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public requestNonce;

    /// @notice Tracking the request status (fullfilled, rejected, pending, or does not exist).
    mapping(bytes32 => RequestStatus) public requestStatus;
    /// @dev Collateral requests from integrating position clients.
    mapping(bytes32 => PositionsCollateralRequest) private _collateralRequests;

    modifier beforeDeadline(uint256 _deadline) {
        if (block.timestamp > _deadline) revert DeadlinePassed();
        _;
    }

    /// @notice Initializes the admin, the fee recipient and the fee percentage on the proxy.
    /// @param _admin The admin address.
    /// @param _feeReceipient The fee recipient address.
    /// @param _feePercentage The fee percentage (in bps).
    function __PositionsRelayer_init(address _admin, address _feeReceipient, uint256 _feePercentage)
        public
        initializer
    {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        feeReceipient = _feeReceipient;
        feePercentage = _feePercentage;
    }

    /// @notice Override required by solidity.
    function hasRole(bytes32 _role, address _account)
        public
        view
        override(IPositionsRelayer, AccessControlUpgradeable)
        returns (bool)
    {
        return super.hasRole(_role, _account);
    }

    /// @notice Allows an operator with relayer role to update the Nft ownership root (merkle root) on all supported chains
    /// with the positions relayer deployment.
    /// @param _nftRoot The new merkle root.
    function updateNFTOwnershipRoot(bytes32 _nftRoot) external onlyRole(RELAYER_ROLE) {
        nftOwnershipRoot = _nftRoot;
        emit NFTOwnershipRootUpdated(_nftRoot);
    }

    /// @notice Function used by the integrating positions clients to emit an event for collateral requests to be
    /// processed by the relayer backend.
    /// @param _collateralRequest The client specific collateral request.
    /// @param signature The signature to verify the collateral request against (on the relayer backend).
    function requestCollateral(PositionsCollateralRequest memory _collateralRequest, bytes memory signature)
        external
        beforeDeadline(_collateralRequest.deadline)
        returns (bytes32 requestId)
    {
        uint256 nonce = ++requestNonce[_collateralRequest.tokenId][block.chainid][_collateralRequest.protocol];

        requestId = UID.generate(nonce, block.chainid, _collateralRequest.tokenId, _collateralRequest.protocol);

        requestStatus[requestId] = RequestStatus.PENDING;
        _collateralRequests[requestId] = _collateralRequest;

        emit CollateralRequest(requestId, _collateralRequest, signature);
    }

    /// @notice Allows an operator with the relayer role to process valid collateral requests from integrating
    /// positions clients, and release tokens. A small fee is applied on each successful request fulfillment.
    /// @param requestId The bytes32 request Id for the collateral request.
    /// @param isApproved Relayer's response to whether the request was approved or rejected.
    /// @return The updated request status
    /// @return errorData The associated error data (if the request failed).
    function processRequest(bytes32 requestId, bool isApproved)
        external
        onlyRole(RELAYER_ROLE)
        returns (RequestStatus, bytes memory errorData)
    {
        if (!isApproved) {
            requestStatus[requestId] = RequestStatus.FAILED;
            emit CollateralProcess(requestId, requestStatus[requestId], errorData);
            return (requestStatus[requestId], errorData);
        }

        PositionsCollateralRequest memory collateralRequest = _collateralRequests[requestId];
        IPositionsClient client = IPositionsClient(collateralRequest.protocol);
        address token = collateralRequest.token;

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        try client.fullfillCollateralRequest(requestId) {
            requestStatus[requestId] = RequestStatus.FULLFILED;
            errorData = "";
        } catch Panic(uint256 errorCode) {
            requestStatus[requestId] = RequestStatus.FAILED;
            errorData = abi.encode(errorCode);
        } catch Error(string memory reason) {
            requestStatus[requestId] = RequestStatus.FAILED;
            errorData = abi.encode(reason);
        } catch (bytes memory lowLevelData) {
            requestStatus[requestId] = RequestStatus.FAILED;
            errorData = lowLevelData;
        }

        if (requestStatus[requestId] == RequestStatus.FULLFILED) {
            uint256 balanceAfter = IERC20(token).balanceOf(address(this));
            uint256 amountReceived = balanceAfter - balanceBefore;
            if (amountReceived < collateralRequest.tokenAmount) {
                requestStatus[requestId] = RequestStatus.FAILED;
                errorData = abi.encode(InsufficientFunds.selector);
            } else {
                uint256 fee = (amountReceived * feePercentage) / 100_00;
                SafeERC20.safeTransfer(IERC20(token), feeReceipient, fee);
                SafeERC20.safeTransfer(IERC20(token), collateralRequest.owner, amountReceived - fee);
            }
        }

        emit CollateralProcess(requestId, requestStatus[requestId], errorData);

        return (requestStatus[requestId], errorData);
    }

    /// @notice Utility function to verify Nft ownership against the stored merkle root. Used by the relayer backend.
    /// @param user The user address.
    /// @param tokenId The user's Nft tokenId.
    /// @param proof The merkle proof.
    function verifyNFTOwnership(address user, uint256 tokenId, bytes32[] calldata proof) external view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user, tokenId));
        return MerkleProof.verify(proof, nftOwnershipRoot, leaf);
    }

    /// @notice Gets the collateral request data for a given requestId.
    /// @param requestId The bytes32 requestId.
    function collateralRequests(bytes32 requestId) external view override returns (PositionsCollateralRequest memory) {
        return _collateralRequests[requestId];
    }

    //TODO: KK, Find a solution to verify the ownership of the NFT on request
    //This can be done off-chain by the relayer.
    function _verifyRequest(PositionsCollateralRequest memory, bytes memory) internal pure returns (bool) {
        return true;
    }

    /// @notice Allows the admin to change the fee recipient.
    /// @param _feeReceipient The new fee recipient.
    function changeFeeReceipient(address _feeReceipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_feeReceipient == address(0)) revert AddressZero();

        feeReceipient = _feeReceipient;
    }

    /// @notice Allows the admin to change the fee percentage (in bps).
    /// @param _feePercentage The new fee percentage.
    function changeFeePercentage(uint256 _feePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_feePercentage >= 10_000) revert InvalidFeePercentage();

        feePercentage = _feePercentage;
    }

    /// @notice Overriding the UUPS upgrade authorization so that it is only callable by operators with the
    /// upgrader role.
    function _authorizeUpgrade(address _newImplementation) internal view override onlyRole(UPGRADE_ROLE) {}
}
