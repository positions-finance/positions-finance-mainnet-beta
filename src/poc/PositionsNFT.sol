// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/token/ERC721/ERC721Upgradeable.sol";

/// @title PositionsNFT.
/// @author Positions Team.
/// @notice The positions Nft serves as a unique identifier to track each user's position. This Nft is behind a proxy
/// (UUPSUpgradeable). The positions Nft serves as the proof of collateral for cross-chain intents.
contract PositionsNFT is Initializable, ERC721Upgradeable, UUPSUpgradeable, AccessControlUpgradeable {
    error CooldownNotElapsed();

    /// @notice Only operators with the relayer role can mint positions Nft for users.
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    /// @notice A cooldown period between consecutive Nft transfers.
    uint256 public constant COOL_DOWN = 300;

    /// @notice Checks if the positions Nft is currently transferrable or not.
    bool public isTransferPaused;
    /// @dev Tracks the total number of Nfts minted so far. Also used as a counter to mint tokenIds.
    uint256 private _totalSupply;
    /// @notice A mapping to track the UNIX timestamp (in seconds) when a positions Nft was last transferred.
    mapping(uint256 => uint256) public lastTransferTimestamp;

    event TransfersPaused();
    event TransfersUnpaused();

    error TransferPaused();
    error PositionsNftAlreadyMinted();

    modifier shouldHavePassedCoolDown(uint256 tokenId) {
        if (block.timestamp - lastTransferTimestamp[tokenId] < COOL_DOWN) {
            revert CooldownNotElapsed();
        }
        _;
    }

    /// @notice Allows the initialization of the proxy.
    /// @param _admin The initial contract admin.
    function initialize(address _admin) public initializer {
        __ERC721_init("PositionsNFT", "PNFT");
        __UUPSUpgradeable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /// @notice Allows an operator with default admin role to pause Nft transfers.
    function pauseTransfers() external onlyRole(DEFAULT_ADMIN_ROLE) {
        isTransferPaused = true;

        emit TransfersPaused();
    }

    /// @notice Allows an operator with default admin role to unpause Nft transfers.
    function unpauseTransfers() external onlyRole(DEFAULT_ADMIN_ROLE) {
        isTransferPaused = false;

        emit TransfersUnpaused();
    }

    /// @notice Allows a relayer to mint a positions Nft to a user address.
    function mint(address to) external onlyRole(RELAYER_ROLE) {
        if (balanceOf(to) > 0) revert PositionsNftAlreadyMinted();

        uint256 tokenId = ++_totalSupply;
        _mint(to, tokenId);
    }

    /// @dev Tracks the total number of Nfts minted so far. Also used as a counter to mint tokenIds.
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /// @notice Overriding transferFrom to check if transfers are paused or if the cooldown period
    /// is still active.
    /// @param from The address to transfer the Nft from.
    /// @param to The address to transfer the Nft to.
    /// @param tokenId The Nft tokenId.
    function transferFrom(address from, address to, uint256 tokenId)
        public
        override
        shouldHavePassedCoolDown(tokenId)
    {
        if (isTransferPaused) revert TransferPaused();

        lastTransferTimestamp[tokenId] = block.timestamp;
        super.transferFrom(from, to, tokenId);
    }

    /// @notice Overriding safeTransferFrom to check if transfers are paused or if the cooldown period
    /// is still active.
    /// @param from The address to transfer the Nft from.
    /// @param to The address to transfer the Nft to.
    /// @param tokenId The Nft tokenId.
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override
        shouldHavePassedCoolDown(tokenId)
    {
        if (isTransferPaused) revert TransferPaused();

        lastTransferTimestamp[tokenId] = block.timestamp;
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /// @notice Overriding the UUPS Upgrade authorization to only allow the default admin to upgrade the proxy implementation.
    /// @param _newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address _newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @notice Override required by solidity.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
