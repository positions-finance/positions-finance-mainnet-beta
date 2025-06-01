// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/token/ERC721/ERC721Upgradeable.sol";

/// @title PositionsNFT.
/// @author Positions Team.
/// @notice The positions Nft serves as a unique identifier to track each user's position.
/// The positions Nft serves as the proof of collateral for cross-chain intents.
contract PositionsNFT is Initializable, ERC721Upgradeable, UUPSUpgradeable, AccessControlUpgradeable {
    /// @notice Only operators with the relayer role can mint positions Nft for users.
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    /// @notice A cooldown period between consecutive Nft transfers.
    uint256 public constant COOL_DOWN = 300;

    /// @notice Checks if the positions Nft is currently transferrable or not.
    bool public isTransferPaused;
    /// @dev Tracks the total number of Nfts minted so far. Also used as a counter to mint tokenIds.
    uint256 public totalSupply;
    /// @notice A mapping to track the UNIX timestamp (in seconds) when a positions Nft was last transferred.
    mapping(uint256 => uint256) public lastTransferTimestamp;

    event TransfersPaused();
    event TransfersUnpaused();

    error CooldownNotElapsed();
    error TransferPaused();
    error PositionsNftAlreadyMinted();

    modifier shouldHavePassedCoolDown(uint256 tokenId) {
        if (block.timestamp - lastTransferTimestamp[tokenId] < COOL_DOWN) {
            revert CooldownNotElapsed();
        }
        _;
    }

    /// @notice Initializes the proxy.
    /// @param _admin The initial admin.
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
    function mint(address _to) external onlyRole(RELAYER_ROLE) {
        if (balanceOf(_to) > 0) revert PositionsNftAlreadyMinted();

        uint256 tokenId = ++totalSupply;
        _mint(_to, tokenId);
    }

    /// @notice Overriding transferFrom to check if transfers are paused or if the cooldown period
    /// is still active.
    /// @param _from The address to transfer the Nft from.
    /// @param _to The address to transfer the Nft to.
    /// @param _tokenId The Nft tokenId.
    function transferFrom(address _from, address _to, uint256 _tokenId)
        public
        override
        shouldHavePassedCoolDown(_tokenId)
    {
        if (isTransferPaused) revert TransferPaused();

        lastTransferTimestamp[_tokenId] = block.timestamp;
        super.transferFrom(_from, _to, _tokenId);
    }

    /// @notice Overriding safeTransferFrom to check if transfers are paused or if the cooldown period
    /// is still active.
    /// @param _from The address to transfer the Nft from.
    /// @param _to The address to transfer the Nft to.
    /// @param _tokenId The Nft tokenId.
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data)
        public
        override
        shouldHavePassedCoolDown(_tokenId)
    {
        if (isTransferPaused) revert TransferPaused();

        lastTransferTimestamp[_tokenId] = block.timestamp;
        super.safeTransferFrom(_from, _to, _tokenId, _data);
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
