// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";

import {IPositionsLendingPool} from "../../interfaces/protocols/lendingPool/IPositionsLendingPool.sol";
import {IPositionsVaultsEntrypoint} from "../../interfaces/entryPoint/IPositionsVaultsEntrypoint.sol";

import {UserVaultBalance} from "../../utils/PositionsDataProvider.sol";

contract PositionsLendingPoolHandler is UUPSUpgradeable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    struct Position {
        uint256 depositAmount;
        uint256 supplyIndexSnapshot;
    }

    /// @dev Upgrader role can upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice The positions vaults entrypoint.
    address public entrypoint;
    /// @notice The lending pool contract address.
    address public lendingPool;
    /// @notice Mapping to store deposits of users.
    mapping(uint256 tokenId => mapping(address asset => Position position)) public positions;

    event EntrypointSet(address indexed newEntrypoint);

    error PositionsLendingPoolHandler__NotEntryPoint();
    error PositionsLendingPoolHandler__TokenAddressMismatch();
    error PositionsLendingPoolHandler__InsufficientBalance(uint256 amountToWithdraw, uint256 withdrawableAmount);

    modifier onlyEntryPoint() {
        if (msg.sender != entrypoint) revert PositionsLendingPoolHandler__NotEntryPoint();
        _;
    }

    /// @notice Initializes the contract.
    /// @param _entryPoint The vaults entrypoint address.
    /// @param _lendingPool The lending pool contract address.
    /// @param _admin The admin address.
    /// @param _upgrader The upgrader address which receives the upgrader role.
    function initialize(address _entryPoint, address _lendingPool, address _admin, address _upgrader)
        public
        initializer
    {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _upgrader);

        entrypoint = _entryPoint;
        lendingPool = _lendingPool;
    }

    /// @notice Allows the admin to set the new entrypoint.
    /// @param _newEntrypoint The new entrypoint contract address.
    function setEntrypoint(address _newEntrypoint) external onlyRole(DEFAULT_ADMIN_ROLE) {
        entrypoint = _newEntrypoint;

        emit EntrypointSet(_newEntrypoint);
    }

    /// @notice Enables a user to depoit into the lending pool, and activate their deposit as collateral.
    /// @param _token The token address.
    /// @param _amount The amount of token to deposit.
    /// @param _tokenId The user's Nft token Id.
    function deposit(address _token, uint256 _amount, uint256 _tokenId, bytes calldata) external onlyEntryPoint {
        IERC20(_token).approve(lendingPool, _amount);
        IPositionsLendingPool(lendingPool).supply(_token, _amount, address(this));

        (,, uint256 supplyIndex,,,) = IPositionsLendingPool(lendingPool).poolData(_token);

        positions[_tokenId][_token] = Position({depositAmount: _amount, supplyIndexSnapshot: supplyIndex});
    }

    /// @notice Queues tokens for withdrawal from the lending pool.
    /// @param _token The token address.
    /// @param _amount The amount of tokens to withdraw.
    /// @param _tokenId The user's Nft token Id.
    /// @param _additionalData The abi encoded token address.
    function queueWithdraw(address _token, uint256 _amount, uint256 _tokenId, bytes calldata _additionalData)
        external
        view
        onlyEntryPoint
    {
        address token = abi.decode(_additionalData, (address));
        if (_token != token) revert PositionsLendingPoolHandler__TokenAddressMismatch();

        (,, uint256 currentSupplyIndex,,,) = IPositionsLendingPool(lendingPool).poolData(_token);
        Position memory position = positions[_tokenId][_token];

        uint256 withdrawableAmount = (currentSupplyIndex * position.depositAmount) / position.supplyIndexSnapshot;
        if (_amount > withdrawableAmount) {
            revert PositionsLendingPoolHandler__InsufficientBalance(_amount, withdrawableAmount);
        }
    }

    /// @notice Withdraw tokens from lending pool.
    /// @param _withdrawData The withdrawal data passed by the entrypoint contract.
    /// @param _to The address to direct the withdrawn tokens to.
    /// @return The token address.
    /// @return The amount of tokens withdrawn.
    function completeWithdraw(IPositionsVaultsEntrypoint.WithdrawData memory _withdrawData, address _to, bytes calldata)
        external
        onlyEntryPoint
        returns (address, uint256)
    {
        address token = address(uint160(_withdrawData.poolOrVault));
        IPositionsLendingPool(lendingPool).withdraw(token, _withdrawData.amount, _to);

        (,, uint256 currentSupplyIndex,,,) = IPositionsLendingPool(lendingPool).poolData(token);
        positions[_withdrawData.tokenId][token].supplyIndexSnapshot = currentSupplyIndex;

        return (token, _withdrawData.amount);
    }

    /// @notice Liquidates a position.
    /// @param _token The token address.
    /// @param _amount The token amount to liquidate.
    /// @param _tokenId The Nft tokenId.
    /// @param _additionalData The additional bytes data to be decoded into the token address.
    function liquidate(address _token, uint256 _amount, uint256 _tokenId, address, bytes calldata _additionalData)
        external
        onlyEntryPoint
    {
        address token = abi.decode(_additionalData, (address));
        if (_token != token) revert PositionsLendingPoolHandler__TokenAddressMismatch();

        (,, uint256 currentSupplyIndex,,,) = IPositionsLendingPool(lendingPool).poolData(_token);
        Position memory position = positions[_tokenId][token];

        uint256 withdrawableAmount = (currentSupplyIndex * position.depositAmount) / position.supplyIndexSnapshot;
        if (_amount > withdrawableAmount) {
            revert PositionsLendingPoolHandler__InsufficientBalance(_amount, withdrawableAmount);
        }

        positions[_tokenId][token].depositAmount -= _amount;
    }

    /// @notice Complete a liquidation and withdraw funds.
    /// @param _withdrawData The withdrawal data passed by the entrypoint contract.
    function completeLiquidation(IPositionsVaultsEntrypoint.WithdrawData memory _withdrawData, bytes calldata)
        external
        onlyEntryPoint
        returns (address, uint256)
    {
        address token = address(uint160(_withdrawData.poolOrVault));
        IPositionsLendingPool(lendingPool).withdraw(token, _withdrawData.amount, _withdrawData.to);

        (,, uint256 currentSupplyIndex,,,) = IPositionsLendingPool(lendingPool).poolData(token);
        positions[_withdrawData.tokenId][token].supplyIndexSnapshot = currentSupplyIndex;

        return (token, _withdrawData.amount);
    }

    /// @notice Callback into the handler once a withdrawal request is accepted.
    /// @param _withdrawalData The withdrawal data.
    function withdrawalRequestAccepted(IPositionsVaultsEntrypoint.WithdrawData memory _withdrawalData)
        external
        onlyEntryPoint
    {
        positions[_withdrawalData.tokenId][address(uint160(_withdrawalData.poolOrVault))].depositAmount -=
            _withdrawalData.amount;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}

    /// @notice Gets a user's Nft tokenId's balance accross all assets.
    /// @param _tokenId The user's nft tokenId.
    function getUserVaultsBalance(uint256 _tokenId) external view returns (UserVaultBalance[] memory) {
        address[] memory assets = IPositionsLendingPool(lendingPool).getSupportedAssets();
        UserVaultBalance[] memory userVaultBalance = new UserVaultBalance[](assets.length);
        uint256 count;

        for (uint256 i; i < assets.length; ++i) {
            (,, uint256 currentSupplyIndex,,,) = IPositionsLendingPool(lendingPool).poolData(assets[i]);
            Position memory position = positions[_tokenId][assets[i]];
            uint256 amount = (currentSupplyIndex * position.depositAmount) / position.supplyIndexSnapshot;

            if (amount == 0) {
                continue;
            }
            userVaultBalance[count++] = UserVaultBalance({
                handler: address(this),
                vaultOrStrategy: lendingPool,
                asset: assets[i],
                balance: amount
            });
        }

        UserVaultBalance[] memory newUserVaultBalance = new UserVaultBalance[](count);

        for (uint256 i; i < newUserVaultBalance.length; ++i) {
            newUserVaultBalance[i] = userVaultBalance[i];
        }

        return newUserVaultBalance;
    }
}
