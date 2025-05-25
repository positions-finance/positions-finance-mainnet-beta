// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC721} from "@openzeppelin-contracts-5.3.0/token/ERC721/IERC721.sol";

import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IERC721Receiver} from "@openzeppelin-contracts-5.3.0/token/ERC721/IERC721Receiver.sol";
import {IPositionsVaultsEntrypoint} from "../../interfaces/entryPoint/IPositionsVaultsEntrypoint.sol";
import {IPositionsRelayer} from "../../interfaces/poc/IPositionsRelayer.sol";

import {UserVaultBalance} from "../../utils/PositionsDataProvider.sol";

contract PositionsUniV3Handler is UUPSUpgradeable, AccessControlUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;

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

    /// @dev Upgrader role can upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @dev Relayer role can call relayer functions.
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    /// @notice The positions relayer address.
    address public relayer;
    /// @notice Address of the Uniswap V3 NonFungiblePositionManager.
    address public nonFungiblePositionManager;
    /// @notice Mapping to store Nft owners.
    mapping(uint256 uniV3NftTokenId => uint256 tokenId) public nftOwners;
    /// @notice Mapping to store user Nfts.
    mapping(uint256 _tokenId => EnumerableSet.UintSet nfts) private userNfts;
    /// @notice Tracking used nonces for each proof of collateral Nft tokenId.
    mapping(uint256 tokenId => uint256 nonces) public nonces;
    /// @notice Tracking data for each withdrawal request.
    mapping(bytes32 requestId => WithdrawData withdrawData) public withdrawData;
    /// @notice Tracking withdrawal data for liquidations.
    mapping(address handler => mapping(uint256 tokenId => WithdrawData withdrawData)) public liquidationData;

    event NonFungiblePositionManagerSet(address indexed nonFungiblePositionManager);
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
    event EntrypointSet(address indexed newEntrypoint);

    error PositionsUniV3Handler__NotEntryPoint();
    error PositionsUniV3Handler__TokenAddressMismatch();
    error PositionsUniV3Handler__InsufficientBalance(uint256 amountToWithdraw, uint256 withdrawableAmount);
    error PositionsUniV3Handler__NFTOwnershipVerificationFailed(address caller, uint256 tokenId);
    error PositionsUniV3Handler__UnacceptedRequest(bytes32 requestId);
    error PositionsUniV3Handler__NotNftOwner();

    /// @notice Initializes the contract.
    /// @param _nonFungiblePositionManager The uniV3 non fungible position manager contract address.
    /// @param _admin The admin address.
    /// @param _upgrader The upgrader address which receives the upgrader role.
    function initialize(address _relayer, address _nonFungiblePositionManager, address _admin, address _upgrader)
        public
        initializer
    {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _upgrader);

        relayer = _relayer;
        nonFungiblePositionManager = _nonFungiblePositionManager;
    }

    /// @notice Allows the admin to set the new non fungible position manager.
    /// @param _nonFungiblePositionManager The new non fungible position manager contract address.
    function setNonFungiblePositionManager(address _nonFungiblePositionManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        nonFungiblePositionManager = _nonFungiblePositionManager;

        emit NonFungiblePositionManagerSet(_nonFungiblePositionManager);
    }

    /// @notice Enables a user to deposit their UniV3 Nft, and activate it as collateral.
    /// @param _token The UniV3 Nft token Id.
    /// @param _tokenId The user's poc Nft token Id.
    /// @param _proof The merkle proof to verify poc Nft ownership.
    function deposit(address, address _token, uint256, uint256 _tokenId, bytes32[] calldata _proof, bytes calldata)
        external
    {
        _validateNFTOwnership(_tokenId, _proof);

        uint256 nftTokenId = uint256(uint160(_token));
        IERC721(nonFungiblePositionManager).safeTransferFrom(msg.sender, address(this), nftTokenId);

        nftOwners[nftTokenId] = _tokenId;
        userNfts[_tokenId].add(nftTokenId);

        emit Deposit(msg.sender, address(uint160(nftTokenId)), address(this), block.chainid, 1, _tokenId);
    }

    /// @notice Queues the Nft for withdrawal.
    /// @param _token The token address.
    /// @param _amount The amount of tokens to withdraw.
    /// @param _tokenId The user's Nft token Id.
    function queueWithdraw(
        address,
        address _token,
        uint256 _amount,
        uint256 _tokenId,
        bytes32[] calldata _proof,
        bytes calldata
    ) external {
        _validateNFTOwnership(_tokenId, _proof);

        if (nftOwners[uint256(uint160(_token))] != _tokenId) revert PositionsUniV3Handler__NotNftOwner();

        bytes32 requestId = keccak256(abi.encode(_tokenId, address(this), nonces[_tokenId]++));
        WithdrawData memory withdrawalData = WithdrawData({
            status: Status.PENDING,
            poolOrVault: uint256(uint160(_token)),
            to: msg.sender,
            tokenId: _tokenId,
            amount: _amount,
            handler: address(this)
        });
        withdrawData[requestId] = withdrawalData;

        emit WithdrawRequest(requestId, msg.sender, _token, address(this), block.chainid, 1, _tokenId);
    }

    /// @notice Withdraw tokens from lending pool.
    function completeWithdraw(address, bytes32 _requestId, bytes32[] calldata _proof, bytes calldata) external {
        WithdrawData memory withdrawalData = withdrawData[_requestId];
        if (withdrawalData.status != Status.ACCEPTED) revert PositionsUniV3Handler__UnacceptedRequest(_requestId);
        _validateNFTOwnership(withdrawalData.tokenId, _proof);

        uint256 tokenId = withdrawalData.poolOrVault;

        withdrawData[_requestId].status = Status.COMPLETED;

        IERC721(nonFungiblePositionManager).safeTransferFrom(address(this), msg.sender, tokenId);

        emit Withdraw(
            _requestId, msg.sender, address(uint160(tokenId)), address(this), block.chainid, 1, withdrawalData.tokenId
        );
    }

    /// @notice Liquidates a position.
    /// @param _token The token address.
    /// @param _amount The token amount to liquidate.
    /// @param _tokenId The Nft tokenId.
    function liquidate(address, address _token, uint256 _amount, uint256 _tokenId, address _liquidator, bytes calldata)
        external
        onlyRole(RELAYER_ROLE)
    {
        WithdrawData memory withdrawalData = WithdrawData({
            status: Status.ACCEPTED,
            poolOrVault: uint256(uint160(_token)),
            to: _liquidator,
            tokenId: _tokenId,
            amount: _amount,
            handler: address(this)
        });
        liquidationData[address(this)][_tokenId] = withdrawalData;

        userNfts[_tokenId].remove(uint256(uint160(_token)));
        delete nftOwners[uint256(uint160(_token))];

        emit Liquidation(_liquidator, _token, address(this), block.chainid, _amount, _tokenId);
    }

    /// @notice Complete a liquidation and withdraw funds.
    function completeLiquidation(address, uint256 _tokenId, bytes calldata) external {
        WithdrawData memory withdrawalData = liquidationData[address(this)][_tokenId];
        liquidationData[address(this)][_tokenId].status = Status.COMPLETED;

        IERC721(nonFungiblePositionManager).safeTransferFrom(
            address(this), withdrawalData.to, withdrawalData.poolOrVault
        );

        emit LiquidationCompleted(
            withdrawalData.to,
            address(uint160(withdrawalData.poolOrVault)),
            address(this),
            block.chainid,
            1,
            withdrawalData.tokenId
        );
    }

    /// @notice Callback into the handler once a withdrawal request is accepted.
    /// @param _withdrawalData The withdrawal data.
    function withdrawalRequestAccepted(IPositionsVaultsEntrypoint.WithdrawData memory _withdrawalData) external {
        userNfts[_withdrawalData.tokenId].remove(_withdrawalData.poolOrVault);
        delete nftOwners[_withdrawalData.poolOrVault];
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _validateNFTOwnership(uint256 _tokenId, bytes32[] calldata _proof) internal view {
        if (!IPositionsRelayer(relayer).verifyNFTOwnership(msg.sender, _tokenId, _proof)) {
            revert PositionsUniV3Handler__NFTOwnershipVerificationFailed(msg.sender, _tokenId);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}

    /// @notice Gets a user's Nft tokenId's balance accross all assets.
    /// @param _tokenId The user's nft tokenId.
    function getUserVaultsBalance(uint256 _tokenId) external view returns (UserVaultBalance[] memory) {
        uint256 length = userNfts[_tokenId].length();
        UserVaultBalance[] memory userVaultBalance = new UserVaultBalance[](length);

        for (uint256 i; i < length; ++i) {
            userVaultBalance[i] = UserVaultBalance({
                handler: address(this),
                vaultOrStrategy: address(this),
                asset: address(uint160(userNfts[_tokenId].at(i))),
                balance: 1
            });
        }

        return userVaultBalance;
    }
}
