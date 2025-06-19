// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPositionsVaultsEntrypoint {
    enum Status {
        NOT_FOUND,
        PENDING,
        ACCEPTED,
        COMPLETED,
        REJECTED
    }

    struct WithdrawData {
        Status status;
        uint256 poolOrVault;
        address to;
        uint256 tokenId;
        uint256 amount;
        address handler;
    }

    /// @dev Emitted when a new relayer address is set.
    /// @param newRelayer The new relayer contract address.
    event RelayerSet(address indexed newRelayer);
    /// @dev Emitted when a new handler is added.
    /// @param _handler The handler contract address.
    event HandlerAdded(address indexed _handler);
    /// @dev Emitted when an existing handler is removed.
    /// @param _handler The handler contract address.
    event HandlerRemoved(address indexed _handler);
    /// @dev Emitted when a token is deposited into a handler.
    /// @param sender The depositor.
    /// @param asset The token being deposited.
    /// @param vault The handler address.
    /// @param chainId The block.chainid.
    /// @param amount The token amount being deposited.
    /// @param tokenId The user's Nft tokenId.
    event Deposit(
        address indexed sender,
        address indexed asset,
        address indexed vault,
        uint256 chainId,
        uint256 amount,
        uint256 tokenId
    );
    ///
    /// @param requestId A unique Id associated with the request.
    /// @param sender The withdrawer.
    /// @param asset The token being withdrawn.
    /// @param vault The handler address.
    /// @param chainId The block.chainid.
    /// @param amount The token amount being withdrawn.
    /// @param tokenId The user's Nft tokenId.
    event WithdrawRequest(
        bytes32 requestId,
        address indexed sender,
        address indexed asset,
        address indexed vault,
        uint256 chainId,
        uint256 amount,
        uint256 tokenId
    );
    /// @dev Emitted on succcessful withdrawal.
    /// @param requestId The unique Id associated with the withdrawal request.
    /// @param sender The withdrawer.
    /// @param asset The token being withdrawn.
    /// @param vault The handler address.
    /// @param chainId The block.chainid.
    /// @param amount The token amount being withdrawn.
    /// @param tokenId The user's Nft tokenId.
    event Withdraw(
        bytes32 requestId,
        address indexed sender,
        address indexed asset,
        address indexed vault,
        uint256 chainId,
        uint256 amount,
        uint256 tokenId
    );
    /// @dev Emitted when a position is liquidated.
    /// @param liquidator The address to direct the liquidated amount to.
    /// @param asset The token being withdrawn.
    /// @param vault The handler address.
    /// @param chainId The block.chainid.
    /// @param amount The token amount being withdrawn.
    /// @param tokenId The user's Nft tokenId.
    event Liquidation(
        address indexed liquidator,
        address indexed asset,
        address indexed vault,
        uint256 chainId,
        uint256 amount,
        uint256 tokenId
    );
    /// @dev Emitted on successful withdrawal from a liquidated position.
    /// @param liquidator The address to direct the liquidated amount to.
    /// @param asset The token being withdrawn.
    /// @param vault The handler address.
    /// @param chainId The block.chainid.
    /// @param amount The token amount being withdrawn.
    /// @param tokenId The user's Nft tokenId.
    event LiquidationCompleted(
        address indexed liquidator,
        address indexed asset,
        address indexed vault,
        uint256 chainId,
        uint256 amount,
        uint256 tokenId
    );

    error PositionsVaultsEntryPoint__AddressZero();
    error PositionsVaultsEntrypoint__UnacceptedRequest(bytes32 requestId);
    error PositionsVaultsEntryPoint__ArrayLengthMismatch();
    error PositionsVaultsEntryPoint__InvalidWithdrawStatus();
    error PositionsVaultsEntrypoint__UnsupportedHandler();
    error PositionsVaultsEntryPoint__NFTOwnershipVerificationFailed(address caller, uint256 tokenId);

    function setPositionsRelayer(address _newRelayer) external;
    function deposit(
        address _handler,
        address _token,
        uint256 _amount,
        uint256 _tokenId,
        bytes calldata _additionalData
    ) external;
    function queueWithdraw(
        address _handler,
        address _token,
        uint256 _amount,
        uint256 _tokenId,
        bytes32[] calldata _proof,
        bytes calldata _additionalData
    ) external returns (bytes32);
    function completeWithdraw(
        address _handler,
        bytes32 _requestId,
        bytes32[] calldata _proof,
        bytes calldata _additionalData
    ) external;
    function liquidate(
        address _handler,
        address _token,
        uint256 _amount,
        uint256 _tokenId,
        address _liquidator,
        bytes calldata _additionalData
    ) external;
    function completeLiquidation(address _handler, uint256 _tokenId, bytes calldata _additionalData) external;
    function setWithdrawalStatus(bytes32[] memory _requestIds, Status[] memory _statuses) external;
    function getSupportedHandlers() external view returns (address[] memory);
}
