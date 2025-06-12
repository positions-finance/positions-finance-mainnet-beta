// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IPositionsRelayer} from "../interfaces/poc/IPositionsRelayer.sol";
import {IPositionsVaultsEntrypoint} from "../interfaces/entryPoint/IPositionsVaultsEntrypoint.sol";
import {IHandler} from "../interfaces/handlers/IHandler.sol";

/// @title PositionsVaultsEntrypoint.
/// @author Positions Team.
/// @notice Single entrypoint contract to deposit and earn rewards from various supported vaults on the
/// positions protocol.
contract PositionsVaultsEntrypoint is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    IPositionsVaultsEntrypoint
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Relayer role can call relayer functions.
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    /// @dev Upgrader role can upgrade the contract.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice The positions relayer address.
    address public relayer;
    /// @dev A set of supported vaults to deposit tokens in and earn rewards.
    EnumerableSet.AddressSet private supportedHandlers;
    /// @notice Tracking used nonces for each proof of collateral Nft tokenId.
    mapping(uint256 tokenId => uint256 nonces) public nonces;
    /// @notice Tracking data for each withdrawal request.
    mapping(bytes32 requestId => WithdrawData withdrawData) public withdrawData;
    /// @notice Tracking withdrawal data for liquidations.
    mapping(address handler => mapping(uint256 tokenId => WithdrawData withdrawData)) public liquidationData;

    /// @notice Sets the admin, upgrader, and relayer, while providing the necessary roles.
    /// @param _admin The admin address.
    /// @param _upgrader The upgrader address.
    /// @param _relayer The positions relayer contract address.
    function initialize(address _admin, address _upgrader, address _relayer) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _upgrader);

        relayer = _relayer;
    }

    /// @notice Admin-only function to set the new relayer address.
    /// @param _newRelayer The new relayer address.
    function setPositionsRelayer(address _newRelayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        relayer = _newRelayer;

        emit RelayerSet(_newRelayer);
    }

    /// @notice Admin-only function to add a new vault handler.
    /// @param _handler The vault handler address.
    function addHandler(address _handler) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_handler == address(0)) revert PositionsVaultsEntryPoint__AddressZero();

        if (supportedHandlers.add(_handler)) {
            emit HandlerAdded(_handler);
        }
    }

    /// @notice Admin-only function to remove an existing vault handler.
    /// @param _handler The vault handler address.
    function removeHandler(address _handler) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_handler == address(0)) revert PositionsVaultsEntryPoint__AddressZero();

        if (supportedHandlers.remove(_handler)) {
            emit HandlerRemoved(_handler);
        }
    }

    /// @notice Allows a user to deposit into a supported vault.
    /// @param _handler The vault handler address.
    /// @param _token The token to deposit.
    /// @param _amount The amount of token to deposit.
    /// @param _tokenId The user's Nft tokenId.
    /// @param _proof Merkle proof to verify Nft ownership.
    /// @param _additionalData Additional handler-specific data.
    function deposit(
        address _handler,
        address _token,
        uint256 _amount,
        uint256 _tokenId,
        bytes32[] calldata _proof,
        bytes calldata _additionalData
    ) external {
        _revertIfUnsupportedHandler(_handler);
        _validateNFTOwnership(_tokenId, _proof);

        IERC20(_token).safeTransferFrom(msg.sender, _handler, _amount);

        IHandler(_handler).deposit(_token, _amount, _tokenId, _additionalData);

        emit Deposit(msg.sender, _token, _handler, block.chainid, _amount, _tokenId);
    }

    /// @notice Allows a user to request for withdrawal from a supported vault.
    /// @param _handler The vault handler address.
    /// @param _token The token to withdraw.
    /// @param _amount The amount of token to withdraw.
    /// @param _tokenId The user's Nft tokenId.
    /// @param _proof Merkle proof to verify Nft ownership.
    /// @param _additionalData Additional handler-specific data.
    function queueWithdraw(
        address _handler,
        address _token,
        uint256 _amount,
        uint256 _tokenId,
        bytes32[] calldata _proof,
        bytes calldata _additionalData
    ) external returns (bytes32) {
        _revertIfUnsupportedHandler(_handler);
        _validateNFTOwnership(_tokenId, _proof);

        bytes32 requestId = keccak256(abi.encode(_tokenId, _handler, nonces[_tokenId]++));
        WithdrawData memory withdrawalData = WithdrawData({
            status: Status.PENDING,
            poolOrVault: abi.decode(_additionalData, (uint256)),
            to: msg.sender,
            tokenId: _tokenId,
            amount: _amount,
            handler: _handler
        });
        withdrawData[requestId] = withdrawalData;

        IHandler(_handler).queueWithdraw(_token, _amount, _tokenId, _additionalData);

        emit WithdrawRequest(requestId, msg.sender, _token, _handler, block.chainid, _amount, _tokenId);

        return requestId;
    }

    /// @notice Complete withdrawal after a withdrawal request is approved.
    /// @param _handler The vault handler address.
    /// @param _requestId The withdrawal requestId.
    /// @param _proof Merkle proof to verify Nft ownership.
    /// @param _additionalData Additional handler-specific data.
    function completeWithdraw(
        address _handler,
        bytes32 _requestId,
        bytes32[] calldata _proof,
        bytes calldata _additionalData
    ) external {
        _revertIfUnsupportedHandler(_handler);

        WithdrawData memory withdrawalData = withdrawData[_requestId];
        if (withdrawalData.status != Status.ACCEPTED) revert PositionsVaultsEntrypoint__UnacceptedRequest(_requestId);
        _validateNFTOwnership(withdrawalData.tokenId, _proof);

        withdrawData[_requestId].status = Status.COMPLETED;

        (address token, uint256 amount) =
            IHandler(_handler).completeWithdraw(withdrawalData, msg.sender, _additionalData);

        emit Withdraw(_requestId, msg.sender, token, _handler, block.chainid, amount, withdrawalData.tokenId);
    }

    /// @notice Allows the relayer to liquidate unhealthy positions.
    /// @param _handler The vault handler address.
    /// @param _token The token to withdraw.
    /// @param _amount The amount of token to withdraw.
    /// @param _tokenId The user's Nft tokenId.
    /// @param _liquidator The liquidator address.
    /// @param _additionalData Additional handler-specific data.
    function liquidate(
        address _handler,
        address _token,
        uint256 _amount,
        uint256 _tokenId,
        address _liquidator,
        bytes calldata _additionalData
    ) external onlyRole(RELAYER_ROLE) {
        _revertIfUnsupportedHandler(_handler);

        WithdrawData memory withdrawalData = WithdrawData({
            status: Status.ACCEPTED,
            poolOrVault: abi.decode(_additionalData, (uint256)),
            to: _liquidator,
            tokenId: _tokenId,
            amount: _amount,
            handler: _handler
        });
        liquidationData[_handler][_tokenId] = withdrawalData;

        IHandler(_handler).liquidate(_token, _amount, _tokenId, _liquidator, _additionalData);

        emit Liquidation(_liquidator, _token, _handler, block.chainid, _amount, _tokenId);
    }

    /// @notice Completes liquidation by withdrawing funds from the handler.
    /// @dev This is to manage vaults which have a waiting period before withdrawal, for e.g. eigen vault.
    /// @param _handler The vault handler address.
    /// @param _tokenId The user's Nft tokenId.
    /// @param _additionalData Additional handler-specific data.
    function completeLiquidation(address _handler, uint256 _tokenId, bytes calldata _additionalData) external {
        _revertIfUnsupportedHandler(_handler);

        WithdrawData memory withdrawalData = liquidationData[_handler][_tokenId];
        liquidationData[_handler][_tokenId].status = Status.COMPLETED;

        (address token, uint256 amount) = IHandler(_handler).completeLiquidation(withdrawalData, _additionalData);

        emit LiquidationCompleted(withdrawalData.to, token, _handler, block.chainid, amount, withdrawalData.tokenId);
    }

    /// @notice Relayer-only function to approve or reject withdrawal requests.
    /// @param _requestIds The withdrawal request Ids.
    /// @param _statuses Approval or rejection statuses for requests.
    function setWithdrawalStatus(bytes32[] memory _requestIds, Status[] memory _statuses)
        external
        onlyRole(RELAYER_ROLE)
    {
        if (_requestIds.length != _statuses.length) {
            revert PositionsVaultsEntryPoint__ArrayLengthMismatch();
        }

        for (uint256 i; i < _requestIds.length; i++) {
            Status status = _statuses[i];

            if (status == Status.ACCEPTED) {
                WithdrawData memory withdrawalData = withdrawData[_requestIds[i]];
                if (withdrawalData.status != Status.PENDING) {
                    revert PositionsVaultsEntryPoint__InvalidWithdrawStatus();
                }
                IHandler(withdrawalData.handler).withdrawalRequestAccepted(withdrawalData);
            }
            withdrawData[_requestIds[i]].status = _statuses[i];
        }
    }

    function _revertIfUnsupportedHandler(address _handler) internal view {
        if (!supportedHandlers.contains(_handler)) revert PositionsVaultsEntrypoint__UnsupportedHandler();
    }

    function _validateNFTOwnership(uint256 _tokenId, bytes32[] calldata _proof) internal view {
        if (!IPositionsRelayer(relayer).verifyNFTOwnership(msg.sender, _tokenId, _proof)) {
            revert PositionsVaultsEntryPoint__NFTOwnershipVerificationFailed(msg.sender, _tokenId);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}

    /// @notice Gets a set of all supported handlers.
    function getSupportedHandlers() external view returns (address[] memory) {
        return supportedHandlers.values();
    }
}
